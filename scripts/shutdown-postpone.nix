{ pkgs }:

# User-facing postpone wrapper. Checks cooldown for a nice UX, then delegates
# all privileged work to shutdown-postpone-helper via sudo NOPASSWD.
# The helper re-enforces the cooldown as defense in depth.

pkgs.writeShellScriptBin "shutdown-postpone" ''
  LAST_FILE="/var/lib/shutdown-timer/postpone-last"
  COOLDOWN_SECONDS=$((5 * 24 * 60 * 60))

  NOW=$(date +%s)
  LAST=0
  if [ -s "$LAST_FILE" ]; then
    LAST_RAW=$(cat "$LAST_FILE" 2>/dev/null || echo 0)
    case "$LAST_RAW" in
      '''|*[!0-9]*) LAST=0 ;;
      *) LAST=$LAST_RAW ;;
    esac
  fi

  ELAPSED=$((NOW - LAST))
  if [ "$ELAPSED" -lt "$COOLDOWN_SECONDS" ]; then
    REMAINING=$((COOLDOWN_SECONDS - ELAPSED))
    NEXT_TIME=$(date -d "@$((NOW + REMAINING))" '+%a %H:%M')
    echo "Postpone already used recently. Next available: $NEXT_TIME."
    ${pkgs.libnotify}/bin/notify-send -u normal -a "Shutdown Postpone" \
      "Already used recently. Next available $NEXT_TIME."
    exit 1
  fi

  OUT=$(sudo /run/current-system/sw/bin/shutdown-postpone-helper 2>&1)
  RC=$?
  if [ "$RC" -ne 0 ]; then
    echo "Postpone failed (helper exited $RC):"
    echo "$OUT"
    ${pkgs.libnotify}/bin/notify-send -u critical -a "Shutdown Postpone" \
      "Postpone failed (code $RC). See terminal / journal."
    exit 1
  fi

  SNOOZE_UNTIL=$(echo "$OUT" | tail -n1)
  SNOOZE_TIME=$(date -d "@$SNOOZE_UNTIL" '+%H:%M')
  echo "Shutdown postponed by 1 hour (until $SNOOZE_TIME). 5-day postpone used."
  ${pkgs.libnotify}/bin/notify-send -u normal -a "Shutdown Postpone" \
    "Shutdown pushed back 1 hour (until $SNOOZE_TIME). 5-day postpone used."
''
