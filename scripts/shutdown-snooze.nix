{ pkgs }:

pkgs.writeShellScriptBin "shutdown-snooze" ''
  HOUR=$(date +%-H)
  if [ "$HOUR" -lt 2 ]; then
    NIGHT_DATE=$(date -d "yesterday" +%Y-%m-%d)
  else
    NIGHT_DATE=$(date +%Y-%m-%d)
  fi

  SNOOZE_FILE="/tmp/shutdown-snooze-''${NIGHT_DATE}"

  if [ -f "$SNOOZE_FILE" ]; then
    echo "Snooze already used tonight. Only one snooze per night."
    ${pkgs.libnotify}/bin/notify-send -u normal -a "Shutdown Snooze" \
      "Snooze already used tonight!"
    exit 1
  fi

  SNOOZE_UNTIL=$(date -d "+30 minutes" +%s)
  echo "$SNOOZE_UNTIL" > "$SNOOZE_FILE"
  SNOOZE_TIME=$(date -d "+30 minutes" '+%H:%M')
  echo "Shutdown snoozed by 30 minutes (until $SNOOZE_TIME)."
  ${pkgs.libnotify}/bin/notify-send -u normal -a "Shutdown Snooze" \
    "Shutdown pushed back 30 minutes (until $SNOOZE_TIME)."
''
