{ pkgs }:

# Pre-check wrapper for nixos-rebuild. Refuses to run inside the
# shutdown-enforcement window so the user cannot rebuild the flake at the
# last minute to strip RefuseManualStop and `systemctl stop` the units.
#
# Not a security guarantee — the raw store-path binary is still reachable via
# `sudo /nix/store/.../nixos-rebuild ...`. Deliberately preserved as an
# "if you really mean it" escape hatch. Every attempt (blocked or allowed)
# is logged via `logger -t discipline-rebuild`.

pkgs.writeShellScriptBin "nixos-rebuild-guard" ''
  CHECK=$(command -v discipline-window-check || echo discipline-window-check)
  LOGGER=${pkgs.util-linux}/bin/logger

  if ! "$CHECK" >/dev/null 2>&1; then
    STATUS=$("$CHECK" --status 2>/dev/null || echo "BLOCKED")
    UNLOCK=$("$CHECK" --next-unlock 2>/dev/null || echo "later")
    ${pkgs.libnotify}/bin/notify-send -u critical -a "Rebuild Guard" \
      "Rebuild blocked. $STATUS" 2>/dev/null || true
    echo "nixos-rebuild blocked: $STATUS" >&2
    echo "Try again at: $UNLOCK" >&2
    "$LOGGER" -t discipline-rebuild "BLOCKED $(date -Is) args=$*"
    exit 1
  fi

  "$LOGGER" -t discipline-rebuild "ALLOWED $(date -Is) args=$*"
  exec sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@"
''
