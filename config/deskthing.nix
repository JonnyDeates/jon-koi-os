{ pkgs, lib, username, ... }:
with lib;

let
  deskThingApp = "/home/${username}/Applications/deskthing-linux-0.11.17.AppImage";

  closeWindow = pkgs.writeShellScript "deskthing-close-window" ''
    sleep 15
    ${pkgs.hyprland}/bin/hyprctl dispatch closewindow deskthing
  '';

  prepareAdb = pkgs.writeShellScript "deskthing-prepare-adb" ''
    # Kill any stale ADB server, then start a fresh one
    ${pkgs.android-tools}/bin/adb kill-server 2>/dev/null || true
    sleep 2
    ${pkgs.android-tools}/bin/adb start-server

    # Wait for the Car Thing to actually be detected (up to 30s)
    echo "deskthing: waiting for device..."
    ${pkgs.android-tools}/bin/adb wait-for-device
    sleep 2
    echo "deskthing: device found"
  '';
in
{
    systemd.user.services.deskThingService = {
        Install = {WantedBy = ["graphical-session.target"];};

    Unit = {
      Description = "Start Desk Thing Service";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      Wants = [ "graphical-session.target" ];
      StartLimitIntervalSec = 120;
      StartLimitBurst = 3;
    };

     Service = {
      Type = "simple";
      # Prepare ADB connection before launching
      ExecStartPre = "${prepareAdb}";
      ExecStart = "${pkgs.appimage-run}/bin/appimage-run ${deskThingApp}";
      ExecStartPost = "${closeWindow}";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStartSec = "60s";
      IOSchedulingClass = "idle";
      };
    };
}
