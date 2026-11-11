{
  pkgs,
  lib,
  username,
  ...
}:

# Self-imposed discipline: nightly shutdown, standing breaks, and the guards
# that make them hard to switch off. steam-blocker.nix is kept but not imported.
{
  imports = [
    ./shutdown-timer.nix
    ./stand-enforcer.nix
  ];

  environment.systemPackages = [
    # Root-run privileged helper for shutdown-postpone. Must live in
    # /run/current-system/sw/bin so sudo's secure_path can find it.
    (import ./shutdown-postpone-helper.nix { inherit pkgs; })
    # Discipline-window rebuild guard + supporting check. In systemPackages
    # (not home.packages) so sudo's secure_path finds them when the shim
    # below reroutes `sudo nixos-rebuild` through the guard.
    (import ./nixos-rebuild-guard.nix { inherit pkgs; })
    (import ./discipline-window-check.nix { inherit pkgs; })
    # Shadow /run/current-system/sw/bin/nixos-rebuild with a shim that
    # exec's the guard. hiPrio wins the buildEnv collision against the
    # real pkgs.nixos-rebuild. Closes the `sudo nixos-rebuild` bypass;
    # raw store-path calls still work by design.
    (lib.hiPrio (
      pkgs.writeShellScriptBin "nixos-rebuild" ''
        exec /run/current-system/sw/bin/nixos-rebuild-guard "$@"
      ''
    ))
  ];

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.user != "${username}") return null;
      if (action.id != "org.freedesktop.systemd1.manage-units" &&
          action.id != "org.freedesktop.systemd1.manage-unit-files") return null;
      var unit = action.lookup("unit");
      var verb = action.lookup("verb");
      var blockedUnits = {
        "shutdown-timer.timer": true,
        "shutdown-check.service": true,
        "steam-blocker.timer": true,
        "steam-blocker.service": true
      };
      var blockedVerbs = { "stop": true, "disable": true };
      if (blockedUnits[unit] && blockedVerbs[verb]) {
        return polkit.Result.NO;
      }
    })
  '';

  security.sudo.extraConfig = ''
    Cmnd_Alias BLOCKED_UNITS = \
      /run/current-system/sw/bin/systemctl stop shutdown-timer, \
      /run/current-system/sw/bin/systemctl stop shutdown-timer.timer, \
      /run/current-system/sw/bin/systemctl stop shutdown-check, \
      /run/current-system/sw/bin/systemctl stop shutdown-check.service, \
      /run/current-system/sw/bin/systemctl stop steam-blocker, \
      /run/current-system/sw/bin/systemctl stop steam-blocker.timer, \
      /run/current-system/sw/bin/systemctl stop steam-blocker.service, \
      /run/current-system/sw/bin/systemctl disable shutdown-timer, \
      /run/current-system/sw/bin/systemctl disable shutdown-timer.timer, \
      /run/current-system/sw/bin/systemctl disable shutdown-check, \
      /run/current-system/sw/bin/systemctl disable shutdown-check.service, \
      /run/current-system/sw/bin/systemctl disable steam-blocker, \
      /run/current-system/sw/bin/systemctl disable steam-blocker.timer, \
      /run/current-system/sw/bin/systemctl disable steam-blocker.service
    ${username} ALL=(ALL) !BLOCKED_UNITS
    ${username} ALL=(root) NOPASSWD: /run/current-system/sw/bin/shutdown-postpone-helper
  '';
}
