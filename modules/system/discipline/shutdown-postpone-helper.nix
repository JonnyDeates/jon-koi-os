{ pkgs }:

# Root-run helper invoked by `shutdown-postpone` via sudo NOPASSWD.
# Does three privileged things atomically:
#   1. Writes the HMAC-signed snooze file to /tmp/shutdown-snooze-<night>.
#   2. Writes the night's date to /var/lib/shutdown-timer/postpone-last
#      (root-owned), so each night can only be postponed once.
#   3. Runs `shutdown -c` to cancel any already-queued systemd shutdown.
#
# Rules (enforced here, not just in the user-facing wrapper):
#   - Only Thu/Fri/Sat nights (deadline 00:00) can be postponed.
#   - Postponing pushes the deadline back exactly 1 hour, to 01:00. Never later.
#   - Once per night.
#
# Exit codes:
#   0 success (last line of stdout is SNOOZE_UNTIL epoch)
#   2 already postponed tonight
#   3 HMAC key unreadable
#   4 snooze file write failed
#   5 not a postpone night (Sun-Wed)
#   6 too late (already past 01:00)

pkgs.writeShellScriptBin "shutdown-postpone-helper" ''
  set -u

  KEY_FILE="/var/lib/shutdown-timer/hmac.key"
  STATE_DIR="/var/lib/shutdown-timer"
  LAST_FILE="$STATE_DIR/postpone-last"

  install -d -m 0755 "$STATE_DIR"

  if [ ! -r "$KEY_FILE" ]; then
    echo "shutdown-postpone-helper: HMAC key unreadable at $KEY_FILE" >&2
    exit 3
  fi

  NOW=$(date +%s)
  HOUR=$(date +%-H)
  if [ "$HOUR" -lt 2 ]; then
    NIGHT_DATE=$(date -d "yesterday" +%Y-%m-%d)
  else
    NIGHT_DATE=$(date +%Y-%m-%d)
  fi
  NIGHT_DOW=$(date -d "$NIGHT_DATE" +%u)

  if [ "$NIGHT_DOW" -lt 4 ] || [ "$NIGHT_DOW" -gt 6 ]; then
    echo "shutdown-postpone-helper: postpone only allowed Thu/Fri/Sat nights" >&2
    exit 5
  fi

  # Night deadline is 00:00 after NIGHT_DATE; postponed deadline is 01:00.
  SNOOZE_UNTIL=$(date -d "$NIGHT_DATE +1 day 01:00" +%s)
  if [ "$NOW" -ge "$SNOOZE_UNTIL" ]; then
    echo "shutdown-postpone-helper: already past 01:00" >&2
    exit 6
  fi

  LAST=$(cat "$LAST_FILE" 2>/dev/null || true)
  if [ "$LAST" = "$NIGHT_DATE" ]; then
    echo "shutdown-postpone-helper: already postponed tonight ($NIGHT_DATE)" >&2
    exit 2
  fi

  SNOOZE_FILE="/tmp/shutdown-snooze-''${NIGHT_DATE}"
  # Parameter-expand the last whitespace-separated field — avoids depending on
  # `awk` being in PATH when invoked via sudo with a restricted secure_path.
  HMAC_RAW=$(printf '%s' "$SNOOZE_UNTIL" | ${pkgs.openssl}/bin/openssl dgst -sha256 -hmac "$(cat "$KEY_FILE")")
  HMAC="''${HMAC_RAW##* }"

  TMP=$(mktemp "''${SNOOZE_FILE}.tmp.XXXXXX") || { echo "mktemp failed" >&2; exit 4; }
  trap 'rm -f "$TMP"' EXIT
  printf '%s|%s\n' "$SNOOZE_UNTIL" "$HMAC" > "$TMP" || exit 4
  chmod 0644 "$TMP"
  mv "$TMP" "$SNOOZE_FILE" || exit 4
  trap - EXIT

  # Cancel any already-queued shutdown. If none pending, shutdown -c exits
  # nonzero — treat that as a no-op, not a failure. (Runs as root directly,
  # so the sudoers block on `sudo shutdown` does not apply here.)
  /run/current-system/sw/bin/shutdown -c 2>/dev/null || true

  # Commit "used tonight" only after the snooze is in place and cancel ran.
  LAST_TMP="''${LAST_FILE}.tmp.$$"
  printf '%s\n' "$NIGHT_DATE" > "$LAST_TMP"
  chmod 0644 "$LAST_TMP"
  mv "$LAST_TMP" "$LAST_FILE"

  echo "$SNOOZE_UNTIL"
''
