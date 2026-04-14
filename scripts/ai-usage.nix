{ pkgs }:
pkgs.writeShellScriptBin "ai-usage" ''
  MINIMAX_KEY="''${MINIMAX_API_KEY:-$(cat ~/.config/ai-keys/minimax 2>/dev/null)}"
  STATS=~/.claude/stats-cache.json
  HISTORY=~/.claude/history.jsonl
  JQ="${pkgs.jq}/bin/jq"

  MONTH_LABEL=$(date +"%B %Y")
  MONTH_START_MS=$(date -d "$(date +%Y-%m-01) 00:00:00 UTC" +%s)000

  # --- Claude Code ---
  # Count this month's prompts live from history.jsonl (awk handles large ints correctly)
  if [ -f "$HISTORY" ]; then
    MONTH_PROMPTS=$(${pkgs.gawk}/bin/awk -F'"timestamp":' \
      'NF>1 {ts=int($2+0); if(ts >= '"$MONTH_START_MS"') count++} END{print count+0}' \
      "$HISTORY")
    TOTAL_PROMPTS=$(${pkgs.gawk}/bin/awk 'END{print NR}' "$HISTORY")
  else
    MONTH_PROMPTS="?"
    TOTAL_PROMPTS="?"
  fi

  if [ -f "$STATS" ]; then
    LAST_DATE=$($JQ -r '.lastComputedDate' "$STATS" 2>/dev/null || echo "?")
    TOTAL_MSG=$($JQ -r '.totalMessages' "$STATS" 2>/dev/null || echo "?")
    TOTAL_SESS=$($JQ -r '.totalSessions' "$STATS" 2>/dev/null || echo "?")

    MODEL_LINES=$($JQ -r '
      .modelUsage | to_entries[] |
      "  \(.key | split("-") | .[0:3] | join("-")):\n    Output: \(.value.outputTokens)  |  Cache reads: \(.value.cacheReadInputTokens)"
    ' "$STATS" 2>/dev/null)

    CLAUDE_TEXT="━━━ Claude Code ━━━\n''${MONTH_LABEL}:\n  Prompts sent: ''${MONTH_PROMPTS}\n\nAll time (cached to ''${LAST_DATE}):\n  Messages: ''${TOTAL_MSG}   Sessions: ''${TOTAL_SESS}\n\nTokens by model:\n''${MODEL_LINES}"
  else
    CLAUDE_TEXT="━━━ Claude Code ━━━\n''${MONTH_LABEL} prompts: ''${MONTH_PROMPTS}\n\n(stats-cache.json not found for totals)"
  fi

  # --- MiniMax ---
  if [ -n "$MINIMAX_KEY" ]; then
    MM=$(${pkgs.curl}/bin/curl -s \
      'https://www.minimax.io/v1/api/openplatform/coding_plan/remains' \
      -H "Authorization: Bearer $MINIMAX_KEY" \
      -H 'Content-Type: application/json')

    MM_LINES=$(echo "$MM" | $JQ -r '
      .model_remains[]? |
      "  \(.model_name): \(.current_interval_usage_count) / \(.current_interval_total_count)  (weekly: \(.current_weekly_usage_count) / \(.current_weekly_total_count))"
    ' 2>/dev/null)

    if [ -n "$MM_LINES" ]; then
      MINIMAX_TEXT="━━━ MiniMax (remaining / total) ━━━\n''${MM_LINES}"
    else
      MINIMAX_TEXT="━━━ MiniMax ━━━\n$(echo "$MM" | $JQ '.' 2>/dev/null || echo "$MM")"
    fi
  else
    MINIMAX_TEXT="━━━ MiniMax ━━━\nNo API key found.\nPlace key in ~/.config/ai-keys/minimax"
  fi

  ${pkgs.yad}/bin/yad \
    --title="AI Usage" \
    --center --width=540 --fixed \
    --text="''${CLAUDE_TEXT}\n\n''${MINIMAX_TEXT}" \
    --text-align=left \
    --button="Close:0"
''
