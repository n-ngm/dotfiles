---
description: 別tmuxペインでClaude Codeにタスクを実行させる
argument-hint: <タスクの説明>
---

# タスク実行: $ARGUMENTS

別のtmuxペインでClaude Codeを起動し、タスクを実行させる。

## 手順

### Step 0: 既存ペインの確認（必須）

`tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command} #{pane_current_path} #{pane_title}'` で既存ペインを確認する。

ペインタイトル（`#{pane_title}`）を見て、これから起動するタスクと**内容が一致・類似**するペインがあれば、それは既に実行中の子Claudeである。compaction で状態が失われていても、ここで認識できる。

該当ペインがあった場合:
- ユーザーに `「pane X.Y で既に <タイトル> が実行中です」` と報告
- 「新たに起動する / 既存ペインを尊重して中止する / 既存ペインに切り替えるだけ」のいずれかを確認
- ユーザーの指示があるまで起動しない

### Step 1: プロンプト確認

`$ARGUMENTS` の内容をもとに、子Claudeに渡すプロンプトを作成する。
作成したプロンプトをユーザーに提示し、確認を取る。

- **対象リポジトリ**: タスク内容から適切なリポジトリを判断する（デフォルト: カレントディレクトリ）。`ls` でディレクトリの存在を確認すること。
- **作業モード**: タスクがコード修正を含むかで決まる
  - **修正あり（worktreeモード）**: peraichi-platform の `tmp/worktree-<repo-name>/<branch-slug>` に git worktree を作り、そこで作業する
  - **修正なし（inplaceモード）**: 対象リポジトリでそのまま作業（調査・レビュー・ドキュメント作成など）
- **プロンプト内容**: 子Claudeに渡す指示

ユーザーの承認を得てから次に進むこと。修正指示があれば反映する。

### Step 2a: worktreeモードの場合

peraichi-platform のルート（`/Users/nagami/Projects/HotStartup/peraichi-platform`）配下の `tmp/worktree-<repo-name>/<branch-slug>` に worktree を作る。`branch-slug` は git ブランチ名の `/` を `-` に変換したもの。

**worktree は必ずデフォルトブランチ（origin/HEAD）から作ること。** カレントブランチから派生させると、進行中の作業が混入してクリーンな修正にならない。

```bash
REPO_DIR="<対象リポジトリの絶対パス>"      # 例: .../apps/domain-back
BRANCH_NAME="<新規ブランチ名>"              # 例: fix/issue-31947-auto-refund
BRANCH_SLUG="${BRANCH_NAME//\//-}"          # 例: fix-issue-31947-auto-refund
WORKTREE_DIR="/Users/nagami/Projects/HotStartup/peraichi-platform/tmp/worktree-$(basename "$REPO_DIR")/$BRANCH_SLUG"

# デフォルトブランチを取得（origin/HEAD を見る）
git -C "$REPO_DIR" remote set-head origin -a >/dev/null 2>&1
DEFAULT_BRANCH=$(git -C "$REPO_DIR" symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')

# 最新のデフォルトブランチを取り込んでから worktree 作成
git -C "$REPO_DIR" fetch origin "$DEFAULT_BRANCH"
git -C "$REPO_DIR" worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" "origin/$DEFAULT_BRANCH"
TASK_DIR="$WORKTREE_DIR"
```

子Claudeの作業終了後、worktree は残る（ユーザーが確認・マージ・削除する）。削除する場合は `git -C "$REPO_DIR" worktree remove "$WORKTREE_DIR"`。

### Step 2b: inplaceモードの場合

```bash
TASK_DIR="<対象リポジトリの絶対パス>"
```

### Step 3: プロンプトファイル作成 + tmuxペインで起動

プロンプトを一時ファイルに書き出し、cdしてからclaude を起動する。

プロンプトファイルは **peraichi-platform の `tmp/` 配下**（`/Users/nagami/Projects/HotStartup/peraichi-platform/tmp/`）に作る。`/tmp/`（システムの一時ディレクトリ）は使わない — プロジェクトの中間成果物は `tmp/` に集約する規約のため。

```bash
PROMPT_FILE="/Users/nagami/Projects/HotStartup/peraichi-platform/tmp/claude-run-<タスク識別子>.md"
cat > "$PROMPT_FILE" << 'PROMPT_EOF'
<確認済みプロンプト>
PROMPT_EOF

# peraichi-platform の .mcp.json を必ず読み込ませる（worktree モードでは対象リポに .mcp.json が無いため playwright 等が使えなくなる）
PLATFORM_MCP_CONFIG="/Users/nagami/Projects/HotStartup/peraichi-platform/.mcp.json"

# -P -F '#{pane_id}' で新規ペインのIDを確実に取得する（select-pane -t :.+ はフォーカス挙動に依存して別ペインを指す不具合があった）
PANE_ID=$(tmux split-window -h -p 50 -P -F '#{pane_id}' "cd '$TASK_DIR' && claude --permission-mode acceptEdits --mcp-config '$PLATFORM_MCP_CONFIG' -- \"\$(cat '$PROMPT_FILE')\" ; rm -f '$PROMPT_FILE'; echo 'Done. Press Enter to close.'; read")

# 起動直後にペインタイトルを設定（compaction後の引き継ぎ用）
# タイトルにはタスク内容を簡潔に入れる（例: "apps/docs の未コミット変更を確認してコミット＆push"）
# allow-rename を off にしないと子プロセスがタイトルを上書きする可能性があるので無効化する
tmux set-option -t "$PANE_ID" -p allow-rename off
tmux select-pane -t "$PANE_ID" -T "<タスクの簡潔な説明>"
```

起動後、ユーザーに以下を案内する:
- `Ctrl-b o` でペイン切り替え
- 子Claude側で権限承認が必要な場合がある
- worktreeモードの場合: 作業先パス・ブランチ名を明示
