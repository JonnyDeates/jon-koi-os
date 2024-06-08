{
  pkgs,
  username,
  lib,
  ...
}:
with lib;
let
  wallsetter = pkgs.writeShellScriptBin "wallsetter" ''
  #!/usr/bin/env bash
  DIRECTORY="/home/${username}/Pictures/Wallpapers"
  if [ -d $DIRECTORY ]; then
    num_files=$(ls -1 $DIRECTORY | wc -l)
    if [ $num_files -lt 3 ]; then
      notify-send -t 9000 "The wallpaper folder is expected to have more than 3 images. Exiting Wallsetter."
      exit
    fi
    
    mapfile -t IMAGES < <(shuf -e "$DIRECTORY"/*.{jpg,jpeg,png,gif} | head -n 3)

    IMG1="''${IMAGES[0]}"
    IMG2="''${IMAGES[1]}"
    IMG3="''${IMAGES[2]}"

    hyprctl hyprpaper preload $IMG1
    
    hyprctl hyprpaper wallpaper DP-1, $IMG1

    hyprctl hyprpaper preload $IMG2
    
    hyprctl hyprpaper wallpaper DP-2, $IMG2

    hyprctl hyprpaper preload $IMG3

    hyprctl hyprpaper wallpaper DP-3, $IMG3

    hyprctl hyprpaper unload all
    
  fi
'';
in
{
  home.packages = [wallsetter];
  
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
        ExecStart = "${wallsetter}/bin/wallsetter";
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
