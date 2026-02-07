#!/bin/bash
# PostToolUse hook: Dartファイル編集後にanalyzeを実行

# 標準入力からJSONを読み取り
INPUT=$(cat)

# tool_inputからfile_pathを抽出
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Dartファイルでなければスキップ
if [[ ! "$FILE_PATH" =~ \.dart$ ]]; then
  exit 0
fi

# テストファイルの場合もスキップ（頻繁な編集があるため）
if [[ "$FILE_PATH" =~ /test/ ]]; then
  exit 0
fi

# apps/mobile配下のファイルのみ対象
if [[ ! "$FILE_PATH" =~ apps/mobile/ ]]; then
  exit 0
fi

# プロジェクトルートに移動
cd "$CLAUDE_PROJECT_DIR/apps/mobile" || exit 0

# 編集されたファイルのみをanalyze
RESULT=$(dart analyze "$FILE_PATH" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  # エラーがある場合、Claudeに通知
  echo "Analyze errors in $FILE_PATH:"
  echo "$RESULT" | grep -E "error|warning" | head -10
  exit 0  # exit 0でstdoutをClaudeに表示
fi

exit 0
