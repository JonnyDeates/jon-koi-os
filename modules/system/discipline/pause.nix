{ pkgs }:

# Away mode: every discipline script exits early until `until` (local time),
# then enforcement resumes on its own — no rebuild needed to turn it back on.
# Saturday night's window runs until Sun 02:00, so ending at Sun 12:00 covers
# it; Sunday's 22:00 shutdown is the first one enforced again.
rec {
  until = "2026-11-29 12:00";

  # Exit 0 while paused. Also on PATH so hypridle can skip suspend.
  bin = pkgs.writeShellScriptBin "discipline-paused" ''
    [ "$(${pkgs.coreutils}/bin/date +%s)" -lt "$(${pkgs.coreutils}/bin/date -d '${until}' +%s)" ]
  '';
  check = "${bin}/bin/discipline-paused";
}
