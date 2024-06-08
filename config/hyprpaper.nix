{
  pkgs,
  username,
  lib,
  ...
}:
with lib;
let 
  wallsetterScript = import ../scripts/wallsetter.nix { inherit pkgs username; };
in
{
  services.hyprpaper = {
    enable = true;

    settings = {
      ipc = "on";
      splash = false;
      splash_offset = 2.0;
    };
  };

  systemd.user = {
    services.wallsetter = {
      Install = {WantedBy = ["graphical-session.target"];};

      Unit = {
        Description = "Set random desktop background using hyprpaper";
        After = ["graphical-session-pre.target"];
        PartOf = ["graphical-session.target"];
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${wallsetterScript}/bin/wallsetter";
        IOSchedulingClass = "idle";
      };
    };

    timers.wallsetter = {
      Unit = {Description = "Set random desktop background using hyprpaper on an interval";};

      Timer = {OnUnitActiveSec = "1h";};

      Install = {WantedBy = ["timers.target"];};
    };
  };
}
