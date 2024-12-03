{ pkgs, lib, username, ... }:
with lib;

let
  deskThingStartScript = pkgs.writeShellScriptBin "deskThingStart" ''
    sleep 0.1
    appimage-run ~/Applications/deskthing-linux-0.9.3-setup.AppImage
  '';
in
{
  # Optionally, you can set up your AppImage's custom dependencies, environment, etc.
  services.deskThingService = {
    enable = true;
  };

  systemd.user = {
    services.deskThingService = lib.mkDefault {
      enable = true;

      Unit = {
        Description = "Start Desk Thing Service";
        After = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${deskThingStartScript}";
        Restart = "on-failure";
        User = username;
        Environment = "DISPLAY=:0";  # Set display environment for X11, modify if needed for Wayland
        WorkingDirectory = "/home/${username}";
      };
    };
  };
}