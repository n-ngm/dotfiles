#!/usr/bin/env node
// Fetch Todoist tasks via mcp-remote (https://ai.todoist.net/mcp) and emit
// them as a sorted Markdown table or JSON.
//
//   node todoist-tasks.mjs [--format text|json] [--limit N] [--verbose]
//
// Auth is handled by mcp-remote's own token cache — make sure you've already
// authenticated once via the MCP client. No API token needed here.

import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import process from 'node:process';

const argv = process.argv.slice(2);
function flag(name, fallback) {
  const i = argv.indexOf(name);
  if (i === -1) return fallback;
  const v = argv[i + 1];
  return v && !v.startsWith('--') ? v : true;
}
const FORMAT = flag('--format', 'text');
const LIMIT = parseInt(flag('--limit', '100'), 10);
const VERBOSE = !!flag('--verbose', false);

const MCP_URL = 'https://ai.todoist.net/mcp';

function callMcp() {
  return new Promise((resolve, reject) => {
    const proc = spawn('npx', ['-y', 'mcp-remote', MCP_URL], {
      stdio: ['pipe', 'pipe', VERBOSE ? 'inherit' : 'pipe'],
    });
    if (!VERBOSE && proc.stderr) proc.stderr.on('data', () => {});

    const pending = new Map();
    let nextId = 1;
    let settled = false;

    const rl = createInterface({ input: proc.stdout });
    rl.on('line', (line) => {
      const s = line.trim();
      if (!s) return;
      let msg;
      try { msg = JSON.parse(s); } catch { return; }
      if (msg.id != null && pending.has(msg.id)) {
        const { resolve: res, reject: rej } = pending.get(msg.id);
        pending.delete(msg.id);
        if (msg.error) rej(new Error(`MCP error: ${msg.error.message || JSON.stringify(msg.error)}`));
        else res(msg.result);
      }
    });

    proc.on('error', (e) => { settled = true; reject(e); });
    proc.on('exit', (code) => {
      if (!settled && pending.size > 0) {
        reject(new Error(`mcp-remote exited (code=${code}) before responding. Retry with --verbose to see stderr.`));
      }
    });

    const send = (msg) => proc.stdin.write(JSON.stringify(msg) + '\n');
    const request = (method, params) => {
      const id = nextId++;
      return new Promise((res, rej) => {
        pending.set(id, { resolve: res, reject: rej });
        send({ jsonrpc: '2.0', id, method, params });
      });
    };
    const notify = (method, params) => send({ jsonrpc: '2.0', method, params });

    (async () => {
      try {
        await request('initialize', {
          protocolVersion: '2024-11-05',
          capabilities: {},
          clientInfo: { name: 'todoist-tasks', version: '1.0.0' },
        });
        notify('notifications/initialized', {});
        const result = await request('tools/call', {
          name: 'find-tasks',
          arguments: { filter: 'all', limit: LIMIT },
        });
        settled = true;
        proc.stdin.end();

        let parsed = result;
        if (result && Array.isArray(result.content)) {
          const textChunk = result.content.find((c) => c.type === 'text');
          if (textChunk) {
            try { parsed = JSON.parse(textChunk.text); }
            catch { parsed = { tasks: [], _raw: textChunk.text }; }
          }
        }
        resolve(parsed);
      } catch (e) {
        settled = true;
        proc.kill();
        reject(e);
      }
    })();
  });
}

const SELF_MARKERS = ['永見', '永見 直樹', 'naoki nagami', 'n_nagami', 'na.nagami'];

function extractFrom(description) {
  if (!description) return '自分';
  const m = description.match(/^\s*From\s+(.+?)(?:\n|$)/m);
  if (!m) return '自分';
  const raw = m[1].trim();
  const lower = raw.toLowerCase();
  if (SELF_MARKERS.some((s) => lower.includes(s.toLowerCase()))) return '自分';
  const surname = raw.split(/[\s_]/)[0];
  return surname ? surname + 'さん' : raw;
}

function extractSlackUrl(description) {
  if (!description) return null;
  const m = description.match(/\[Slack\]\((https?:\/\/[^\s)]+)\)/);
  return m ? m[1] : null;
}

// Slack スレッドの識別子を取り出す。
// thread_ts クエリがあればそれを、無ければ /pXXXXXXXXXXXXXXXX（=ts のドット無し表記）から復元する。
// cid（チャンネルID）はスレッド判定に使わない方針。
function extractThreadTs(url) {
  if (!url) return '';
  const q = url.match(/thread_ts=([\d.]+)/);
  if (q) return q[1];
  const p = url.match(/\/p(\d{16})/);
  if (p) return `${p[1].slice(0, 10)}.${p[1].slice(10)}`;
  return '';
}

function slackUrlToJst(url) {
  if (!url) return '';
  const m = url.match(/\/p(\d{10})\d+/);
  if (!m) return '';
  const d = new Date(parseInt(m[1], 10) * 1000);
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('ja-JP', {
      timeZone: 'Asia/Tokyo',
      month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false,
    }).formatToParts(d).map((p) => [p.type, p.value])
  );
  return `${parts.month}/${parts.day} ${parts.hour}:${parts.minute}`;
}

function formatDue(due) {
  if (!due) return '';
  return due.replace('T', ' ').slice(0, 16);
}

const PRI_ORDER = { p1: 1, p2: 2, p3: 3, p4: 4 };

function enrich(tasks) {
  return tasks.map((t) => {
    const slackUrl = extractSlackUrl(t.description);
    return {
      id: t.id,
      content: t.content || '',
      description: t.description || '',
      priority: t.priority,
      from: extractFrom(t.description),
      posted_at_jst: slackUrlToJst(slackUrl),
      slack_url: slackUrl,
      thread_ts: extractThreadTs(slackUrl),
      due: formatDue(t.dueDate),
      recurring: t.recurring || false,
      project_id: t.projectId,
      labels: t.labels || [],
    };
  });
}

function escapeCell(s) {
  return (s || '').replace(/\|/g, '\\|').replace(/\r?\n/g, '<br>');
}

function sortTasks(rows) {
  return rows.slice().sort((a, b) => {
    const pa = PRI_ORDER[a.priority] ?? 9;
    const pb = PRI_ORDER[b.priority] ?? 9;
    if (pa !== pb) return pa - pb;
    if (a.posted_at_jst && b.posted_at_jst) return a.posted_at_jst.localeCompare(b.posted_at_jst);
    if (a.posted_at_jst) return -1;
    if (b.posted_at_jst) return 1;
    return 0;
  });
}

// ソート済みリストを、同一 thread_ts のタスクが連続するよう並べ替える。
// 各スレッドはその最先頭メンバーの位置にアンカーされ、後続メンバーが直下に続く。
// 2件以上あるスレッドの非先頭メンバーには is_thread_child=true を付与する（ツリー描画用）。
function groupByThread(sorted) {
  const counts = {};
  for (const t of sorted) if (t.thread_ts) counts[t.thread_ts] = (counts[t.thread_ts] || 0) + 1;
  const placed = new Set();
  const out = [];
  for (const t of sorted) {
    if (placed.has(t.id)) continue;
    out.push({ ...t, is_thread_child: false });
    placed.add(t.id);
    if (t.thread_ts && counts[t.thread_ts] > 1) {
      for (const u of sorted) {
        if (placed.has(u.id) || u.thread_ts !== t.thread_ts) continue;
        out.push({ ...u, is_thread_child: true });
        placed.add(u.id);
      }
    }
  }
  return out;
}

function renderText(rows) {
  const grouped = groupByThread(sortTasks(rows));
  const lines = [
    '| # | 内容 | 優先度 | 依頼元 | 投稿日時 | URL |',
    '|---|------|--------|--------|----------|-----|',
  ];
  grouped.forEach((t, i) => {
    let body = t.due ? `${t.content}（期限: ${t.due}）` : t.content;
    if (t.is_thread_child) body = `┗ ${body}`;
    const url = t.slack_url ? `[Slack](${t.slack_url})` : '';
    lines.push(`| ${i + 1} | ${escapeCell(body)} | ${t.priority} | ${t.from} | ${t.posted_at_jst} | ${url} |`);
  });
  return lines.join('\n');
}

(async () => {
  try {
    const result = await callMcp();
    const tasks = result?.tasks || [];
    const rows = enrich(tasks);
    if (FORMAT === 'json') {
      console.log(JSON.stringify(groupByThread(sortTasks(rows)), null, 2));
    } else {
      console.log(renderText(rows));
    }
  } catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
  }
})();
