{ pkgs, lib, username, ... }:
with lib;

let
  deskThingApp = "/home/${username}/Applications/deskthing-linux-0.11.17.AppImage";

  closeWindow = pkgs.writeShellScript "deskthing-close-window" ''
    sleep 15
    ${pkgs.hyprland}/bin/hyprctl dispatch closewindow deskthing
  '';

  prepareAdb = pkgs.writeShellScript "deskthing-prepare-adb" ''
    # Poll for up to 30s — Superbird can be slow to enumerate on cold boot.
    for i in $(seq 1 15); do
      if ${pkgs.usbutils}/bin/lsusb -d 1d6b:1014 > /dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    if ! ${pkgs.usbutils}/bin/lsusb -d 1d6b:1014 > /dev/null 2>&1; then
      echo "deskthing: Superbird not on USB after 30s, exiting (udev will retrigger on hotplug)"
      exit 1
    fi

    ${pkgs.android-tools}/bin/adb kill-server 2>/dev/null || true
    sleep 2
    ${pkgs.android-tools}/bin/adb start-server

    echo "deskthing: waiting for device..."
    if ! timeout 15 ${pkgs.android-tools}/bin/adb wait-for-device; then
      echo "deskthing: device did not appear within 15s, exiting"
      exit 1
    fi
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

    # Launcher tile — clears any prior failed/rate-limit state then starts the service.
    # Icon expects /home/<user>/.local/share/icons/hicolor/512x512/apps/deskthing.png
    home.file.".local/share/applications/deskthing.desktop".text = ''
      [Desktop Entry]
      Name=DeskThing
      Comment=Spotify Car Thing companion
      Exec=sh -c 'systemctl --user reset-failed deskThingService 2>/dev/null; systemctl --user start deskThingService'
      Icon=deskthing
      Terminal=false
      Type=Application
      Categories=Utility;
      StartupWMClass=DeskThing
    '';
}
