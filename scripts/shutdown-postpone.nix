{ pkgs }:

pkgs.writeShellScriptBin "shutdown-postpone" ''
  KEY_FILE="/var/lib/shutdown-timer/hmac.key"
  STATE_DIR="$HOME/.local/state"
  LAST_FILE="$STATE_DIR/shutdown-postpone-last"
  mkdir -p "$STATE_DIR"

  if [ ! -r "$KEY_FILE" ]; then
    echo "Cannot read HMAC key at $KEY_FILE. Postpone disabled."
    ${pkgs.libnotify}/bin/notify-send -u critical -a "Shutdown Postpone" \
      "HMAC key unreadable. Postpone disabled."
    exit 1
  fi

  NOW=$(date +%s)
  WEEK_SECONDS=$((7 * 24 * 60 * 60))

  if [ -f "$LAST_FILE" ]; then
    LAST=$(cat "$LAST_FILE")
    ELAPSED=$((NOW - LAST))
    if [ "$ELAPSED" -lt "$WEEK_SECONDS" ]; then
      REMAINING=$((WEEK_SECONDS - ELAPSED))
      NEXT_TIME=$(date -d "@$((NOW + REMAINING))" '+%a %H:%M')
      echo "Postpone already used this week. Next available: $NEXT_TIME."
      ${pkgs.libnotify}/bin/notify-send -u normal -a "Shutdown Postpone" \
        "Already used this week. Next available $NEXT_TIME."
      exit 1
    fi
  fi

  HOUR=$(date +%-H)
  if [ "$HOUR" -lt 2 ]; then
    NIGHT_DATE=$(date -d "yesterday" +%Y-%m-%d)
  else
    NIGHT_DATE=$(date +%Y-%m-%d)
  fi

  SNOOZE_FILE="/tmp/shutdown-snooze-''${NIGHT_DATE}"
  SNOOZE_UNTIL=$(date -d "+2 hours" +%s)
  HMAC=$(printf '%s' "$SNOOZE_UNTIL" | ${pkgs.openssl}/bin/openssl dgst -sha256 -hmac "$(cat "$KEY_FILE")" | awk '{print $NF}')
  echo "''${SNOOZE_UNTIL}|''${HMAC}" > "$SNOOZE_FILE"
  echo "$NOW" > "$LAST_FILE"

  SNOOZE_TIME=$(date -d "+2 hours" '+%H:%M')
  echo "Shutdown postponed by 2 hours (until $SNOOZE_TIME). Weekly postpone used."
  ${pkgs.libnotify}/bin/notify-send -u normal -a "Shutdown Postpone" \
    "Shutdown pushed back 2 hours (until $SNOOZE_TIME). Weekly postpone used."
''
