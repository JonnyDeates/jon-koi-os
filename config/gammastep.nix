{ pkgs, ... }:
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
        night = 3000;
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
}
