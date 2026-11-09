{ pkgs, lib, username, ... }:
with lib;

let
  deskThingApp = "/home/${username}/Applications/deskthing-linux-0.11.17.AppImage";

  closeWindow = pkgs.writeShellScript "deskthing-close-window" ''
    # Wait up to 60s for DeskThing's window to show up — on cold boot the
    # Electron app can take a while to render.
    for i in $(seq 1 30); do
      if ${pkgs.hyprland}/bin/hyprctl clients | ${pkgs.gnugrep}/bin/grep -q "class: deskthing"; then
        break
      fi
      sleep 2
    done
    # Let it finish connecting before we tuck it away.
    sleep 5
    # closewindow sends a close signal (not SIGKILL), so DeskThing's own
    # minimise-to-tray handler runs instead of the process dying.
    ${pkgs.hyprland}/bin/hyprctl dispatch closewindow "class:^(deskthing)$"
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

  # Handles deskthing:// URIs from the browser after OAuth.
  # With no argument: starts the service (app launcher behaviour).
  # With a deskthing:// URI: launches a second AppImage instance with the URI — Electron's
  # single-instance lock forwards it to the already-running process via IPC.
  uriHandler = pkgs.writeShellScript "deskthing-uri-handler" ''
    URI=''${1:-}
    if [ -z "$URI" ]; then
      systemctl --user reset-failed deskThingService 2>/dev/null || true
      systemctl --user start deskThingService
      exit 0
    fi
    ${pkgs.appimage-run}/bin/appimage-run ${deskThingApp} "$URI" &
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
      StartLimitIntervalSec = 600;
      StartLimitBurst = 10;
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
    # Also handles deskthing:// OAuth callbacks via uriHandler above.
    # Icon expects /home/<user>/.local/share/icons/hicolor/512x512/apps/deskthing.png
    home.file.".local/share/applications/deskthing.desktop".text = ''
      [Desktop Entry]
      Name=DeskThing
      Comment=Spotify Car Thing companion
      Exec=${uriHandler} %u
      Icon=deskthing
      Terminal=false
      Type=Application
      Categories=Utility;
      StartupWMClass=DeskThing
      MimeType=x-scheme-handler/deskthing;
    '';
}
