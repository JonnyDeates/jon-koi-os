{ pkgs, lib, username, ... }:
with lib;

let
  deskThingApp = "/home/${username}/Applications/deskthing-linux-0.11.17.AppImage";
in
{
    systemd.user.services.deskThingService = {
        Install = {WantedBy = ["graphical-session.target"];};

    Unit = {
      Description = "Start Desk Thing Service";
      After = [ "graphical-session.target" "network-online.target" ];
      PartOf = [ "graphical-session.target" ];
      Wants = [ "graphical-session.target" ];
    };

     Service = {
      Type = "simple";
     ExecStart = ''
                ${pkgs.coreutils}/bin/setsid -f \
                  ${pkgs.appimage-run}/bin/appimage-run ${deskThingApp}
              '';
     ExecStartPost = ''
                ${pkgs.bash}/bin/bash -lc \
                   'sleep 15; ${pkgs.hyprland}/bin/hyprctl dispatch closewindow deskthing' &
              '';
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStartSec = "15s";  # fail fast instead of hanging HM for 5 minutes
      IOSchedulingClass = "idle";
      };
    };
}