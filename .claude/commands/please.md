---
description: 別ペインでClaude Codeにタスクを実行させる（cmux / tmux 両対応）
argument-hint: <タスクの説明>
---

# タスク実行: $ARGUMENTS

別のペインで Claude Code を起動し、タスクを実行させる。

## 共通変数

すべての手順でこれを前提にする。

```bash
PLATFORM_DIR="${PERAICHI_PLATFORM_DIR:-$HOME/Projects/HotStartup/peraichi-platform}"
```

## Step 0: マルチプレクサの判定（必須）

```bash
if [ -n "$CMUX_SOCKET_PATH" ] && command -v cmux >/dev/null 2>&1; then
  MUX=cmux
elif [ -n "$TMUX" ] && command -v tmux >/dev/null 2>&1; then
  MUX=tmux
else
  MUX=none
fi
```

`MUX=none` の場合はペインを分割できない。ユーザーにその旨を伝えて中止する。

## Step 1: 既存ペインの確認（必須）

これから起動するタスクと内容が一致・類似するペインがあれば、それは既に実行中の子Claudeである。
compaction で状態が失われていても、ここで認識できる。

cmux の場合:

```bash
cmux tree --all
```

surface のタイトルは Claude 起動時に cmux が自動でタスク内容に更新するため、そのまま識別に使える。

tmux の場合:

```bash
tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command} #{pane_current_path} #{pane_title}'
```

該当ペインがあった場合:

- ユーザーに `「<ペイン識別子> で既に <タイトル> が実行中です」` と報告
- 「新たに起動する / 既存ペインを尊重して中止する / 既存ペインに切り替えるだけ」のいずれかを確認
- ユーザーの指示があるまで起動しない

## Step 2: プロンプト確認

`$ARGUMENTS` の内容をもとに、子Claudeに渡すプロンプトを作成する。
作成したプロンプトをユーザーに提示し、確認を取る。

- 対象リポジトリ: タスク内容から適切なリポジトリを判断する（デフォルト: カレントディレクトリ）。`ls` でディレクトリの存在を確認すること。
- 作業モード: タスクがコード修正を含むかで決まる
  - 修正あり（worktreeモード）: peraichi-platform の `tmp/worktree-<repo-name>/<branch-slug>` に git worktree を作り、そこで作業する
  - 修正なし（inplaceモード）: 対象リポジトリでそのまま作業（調査・レビュー・ドキュメント作成など）
- プロンプト内容: 子Claudeに渡す指示

ユーザーの承認を得てから次に進むこと。修正指示があれば反映する。

## Step 3a: worktreeモードの場合

`$PLATFORM_DIR/tmp/worktree-<repo-name>/<branch-slug>` に worktree を作る。
`branch-slug` は git ブランチ名の `/` を `-` に変換したもの。

worktree は必ずデフォルトブランチ（origin/HEAD）から作ること。
カレントブランチから派生させると、進行中の作業が混入してクリーンな修正にならない。

```bash
REPO_DIR="<対象リポジトリの絶対パス>"      # 例: $PLATFORM_DIR/apps/domain-back
BRANCH_NAME="<新規ブランチ名>"              # 例: fix/issue-31947-auto-refund
BRANCH_SLUG="${BRANCH_NAME//\//-}"          # 例: fix-issue-31947-auto-refund
WORKTREE_DIR="$PLATFORM_DIR/tmp/worktree-$(basename "$REPO_DIR")/$BRANCH_SLUG"

# デフォルトブランチを取得（origin/HEAD を見る）
git -C "$REPO_DIR" remote set-head origin -a >/dev/null 2>&1
DEFAULT_BRANCH=$(git -C "$REPO_DIR" symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')

# 最新のデフォルトブランチを取り込んでから worktree 作成
git -C "$REPO_DIR" fetch origin "$DEFAULT_BRANCH"
git -C "$REPO_DIR" worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" "origin/$DEFAULT_BRANCH"
TASK_DIR="$WORKTREE_DIR"
```

子Claudeの作業終了後、worktree は残る（ユーザーが確認・マージ・削除する）。
削除する場合は `git -C "$REPO_DIR" worktree remove "$WORKTREE_DIR"`。

## Step 3b: inplaceモードの場合

```bash
TASK_DIR="<対象リポジトリの絶対パス>"
```

## Step 4: プロンプトファイル作成

プロンプトファイルは peraichi-platform の `tmp/` 配下に作る。
`/tmp/`（システムの一時ディレクトリ）は使わない — プロジェクトの中間成果物は `tmp/` に集約する規約のため。

```bash
PROMPT_FILE="$PLATFORM_DIR/tmp/claude-please-<タスク識別子>.md"
cat > "$PROMPT_FILE" << 'PROMPT_EOF'
<確認済みプロンプト>
PROMPT_EOF

# peraichi-platform の .mcp.json を必ず読み込ませる
# （worktree モードでは対象リポに .mcp.json が無いため playwright 等が使えなくなる）
PLATFORM_MCP_CONFIG="$PLATFORM_DIR/.mcp.json"

CHILD_CMD="cd '$TASK_DIR' && claude --permission-mode acceptEdits --mcp-config '$PLATFORM_MCP_CONFIG' -- \"\$(cat '$PROMPT_FILE')\" ; rm -f '$PROMPT_FILE'; echo 'Done. Press Enter to close.'; read"
```

## Step 5a: cmux で起動

`new-split` は `OK surface:<n> workspace:<n>` を返すので、2列目が surface ref。

```bash
SURFACE=$(cmux new-split right --focus false | awk '{print $2}')

# 起動前の目印としてタイトルを付ける（Claude 起動後は cmux が自動でタスク名に更新する）
cmux rename-tab --surface "$SURFACE" "<タスクの簡潔な説明>"

cmux send --surface "$SURFACE" "$CHILD_CMD"
cmux send-key --surface "$SURFACE" Enter
```

子の進捗は親から覗ける。

```bash
cmux read-screen --surface "$SURFACE" --lines 40
```

## Step 5b: tmux で起動

```bash
# -P -F '#{pane_id}' で新規ペインのIDを確実に取得する
# （select-pane -t :.+ はフォーカス挙動に依存して別ペインを指す不具合があった）
PANE_ID=$(tmux split-window -h -p 50 -P -F '#{pane_id}' "$CHILD_CMD")

# 起動直後にペインタイトルを設定（compaction後の引き継ぎ用）
# タイトルにはタスク内容を簡潔に入れる（例: "apps/docs の未コミット変更を確認してコミット＆push"）
# allow-rename を off にしないと子プロセスがタイトルを上書きする可能性があるので無効化する
tmux set-option -t "$PANE_ID" -p allow-rename off
tmux select-pane -t "$PANE_ID" -T "<タスクの簡潔な説明>"
```

子の進捗は親から覗ける。

```bash
tmux capture-pane -p -t "$PANE_ID" -S -40
```

## Step 6: ユーザーへの案内

起動後、以下を伝える。

- ペイン切り替え方法（cmux: クリックまたは `cmux focus-pane`、tmux: `Ctrl-b o`）
- 子Claude側で権限承認が必要な場合がある
- worktreeモードの場合: 作業先パス・ブランチ名を明示
