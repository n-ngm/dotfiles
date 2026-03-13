---
model: sonnet
---

# Togetterニュースピックアップ

Togetterのトップページにアクセスして、人気のまとめ記事からランダムに1つピックアップして、VoiceVox MCPを使って概要とコメントを読み上げてください。

## 手順
1. https://togetter.com/ にアクセスして人気記事を取得
2. ランダムに1つ選ぶ
3. 選んだ記事の詳細ページにアクセスして、面白いコメントを2〜3個ピックアップ
4. VoiceVoxで以下を読み上げる：
   - 記事タイトルと概要
   - ピックアップしたコメント

## 音声設定
- `~/.claude/scripts/voicebox/current_speaker.conf` の値を読み取り、対応する口調設定ファイル（`~/.claude/scripts/voicebox/speaker_XXX.yaml`）に従うこと
- speaker_id と speed は口調設定ファイルの `voice.speaker_id` と `voice.speed` を使用すること
- auto_play: true

## 読み上げルール
- 1回の音声は100文字以内で簡潔に
- 複数回に分けてOK
- コメントは要約して読み上げてもOK
