{ pkgs, lib, username, ... }:
with lib;

let
  gammastartScript = pkgs.writeShellScriptBin "gammastart" ''
    sleep 0.1
    gammastep -c ~/.config/gammastep/config.ini
  '';
in
{
  home.packages = with pkgs; [
    gammastep
  ];

  services.gammastep = {
      enable = true;
      latitude = "30.633";
      longitude = "97.678";
      dawnTime = "6:00-7:00";
      duskTime = "16:00-22:00";
      provider = "manual";
      temperature = {
        day = 6500;
        night = 2500;
      };
      settings = {
        general = {
          adjustment-method = "wayland";
          brightness-day = "1.0";
          brightness-night = "0.7";
          gamma-day = "1.0";
          gamma-night = "0.6";
        };
      };
    };

systemd.user = {
    services.gammastep = lib.mkDefault {
      enable = true;

      Unit = {
        Description = "Start gammastep to adjust display color temperature";
        After = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${gammastartScript}";
        Restart = "on-failure";
        User = username;
        Environment = "DISPLAY=:0";  # Set display environment for X11, modify if needed for Wayland
        WorkingDirectory = "/home/${username}";
      };
    };
  };
}