{ pkgs }:

# User-facing postpone wrapper. All rules (Thu/Fri/Sat only, once per night,
# never past 01:00) are enforced by shutdown-postpone-helper; this just
# calls it via sudo NOPASSWD and turns its exit code into a friendly message.

pkgs.writeShellScriptBin "shutdown-postpone" ''
  notify() {
    ${pkgs.libnotify}/bin/notify-send -u "$1" -a "Shutdown Postpone" "$2"
  }

  OUT=$(sudo /run/current-system/sw/bin/shutdown-postpone-helper 2>&1)
  RC=$?
  case "$RC" in
    0) ;;
    2) MSG="Already postponed tonight. Shutdown stays at 01:00." ;;
    5) MSG="Postpone is only available Thursday, Friday and Saturday nights." ;;
    6) MSG="Too late. 01:00 is the latest you can stay up." ;;
    *) MSG="Postpone failed (code $RC): $OUT" ;;
  esac
  if [ "$RC" -ne 0 ]; then
    echo "$MSG"
    notify normal "$MSG"
    exit 1
  fi

  SNOOZE_UNTIL=$(echo "$OUT" | tail -n1)
  SNOOZE_TIME=$(date -d "@$SNOOZE_UNTIL" '+%H:%M')
  echo "Shutdown postponed by 1 hour (until $SNOOZE_TIME). That's the max for tonight."
  notify normal "Shutdown pushed back 1 hour (until $SNOOZE_TIME). That's the max for tonight."
''
