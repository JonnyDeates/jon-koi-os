{ pkgs, lib, username, ... }:
with lib;

let
  deskThingStartScript = pkgs.writeShellScriptBin "deskThingStart" ''
    sleep 0.1
    adb reboot
    sleep 0.3
    appimage-run ~/Applications/deskthing-linux-0.9.3-setup.AppImage
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