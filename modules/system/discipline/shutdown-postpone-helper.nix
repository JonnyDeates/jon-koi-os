{ pkgs }:

# Root-run helper invoked by `shutdown-postpone` via sudo NOPASSWD.
# Does three privileged things atomically:
#   1. Writes the HMAC-signed snooze file to /tmp/shutdown-snooze-<night>.
#   2. Writes NOW to /var/lib/shutdown-timer/postpone-last (root-owned).
#   3. Runs `shutdown -c` to cancel any already-queued systemd shutdown.
# Enforces the 5-day cooldown independently so a direct call to the helper
# cannot bypass the gate in the user-facing wrapper.
#
# Exit codes:
#   0 success (last line of stdout is SNOOZE_UNTIL epoch)
#   2 cooldown not yet elapsed
#   3 HMAC key unreadable
#   4 snooze file write failed

pkgs.writeShellScriptBin "shutdown-postpone-helper" ''
  set -u

  KEY_FILE="/var/lib/shutdown-timer/hmac.key"
  STATE_DIR="/var/lib/shutdown-timer"
  LAST_FILE="$STATE_DIR/postpone-last"
  COOLDOWN_SECONDS=$((5 * 24 * 60 * 60))

  install -d -m 0755 "$STATE_DIR"

  if [ ! -r "$KEY_FILE" ]; then
    echo "shutdown-postpone-helper: HMAC key unreadable at $KEY_FILE" >&2
    exit 3
  fi

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
    echo "shutdown-postpone-helper: cooldown not elapsed (ELAPSED=$ELAPSED < COOLDOWN=$COOLDOWN_SECONDS)" >&2
    exit 2
  fi

  HOUR=$(date +%-H)
  if [ "$HOUR" -lt 2 ]; then
    NIGHT_DATE=$(date -d "yesterday" +%Y-%m-%d)
  else
    NIGHT_DATE=$(date +%Y-%m-%d)
  fi

  SNOOZE_FILE="/tmp/shutdown-snooze-''${NIGHT_DATE}"
  SNOOZE_UNTIL=$((NOW + 1 * 60 * 60))
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
  # nonzero — treat that as a no-op, not a failure.
  /run/current-system/sw/bin/shutdown -c 2>/dev/null || true

  # Commit the cooldown only after the snooze is in place and cancel ran.
  LAST_TMP="''${LAST_FILE}.tmp.$$"
  printf '%s\n' "$NOW" > "$LAST_TMP"
  chmod 0644 "$LAST_TMP"
  mv "$LAST_TMP" "$LAST_FILE"

  echo "$SNOOZE_UNTIL"
''
