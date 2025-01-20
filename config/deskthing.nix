{ pkgs, lib, username, ... }:
with lib;

let
  deskThingStartScript = pkgs.writeShellScriptBin "deskThingStart" ''
    sleep 0.1
    sudo adb reboot
    sleep 0.1
    appimage-run ~/Applications/deskthing-linux-0.10.3-setup.AppImage
    sleep 15 && hyprctl dispatch closewindow deskthing
  '';
in
{
    systemd.user.services.deskThingService = {
        Install = {WantedBy = ["graphical-session.target"];};

            Unit = {
              Description = "Start Desk Thing Service";
              After = ["graphical-session.target"];
            };

     Service = {
        Type = "oneshot";
        ExecStart = "${deskThingStartScript}/bin/deskThingStart";
        IOSchedulingClass = "idle";
      };
    };
}