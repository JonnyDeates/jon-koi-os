{
  lib,
  pkgs,
  config,
  ...
}:
{
# Styling Options
  stylix = {
    image = ../../config/wallpapers/jonkoios.png;
    # base16Scheme = {
    #   base00 = "232136";
    #   base01 = "2a273f";
    #   base02 = "393552";
    #   base03 = "6e6a86";
    #   base04 = "908caa";
    #   base05 = "e0def4";
    #   base06 = "e0def4";
    #   base07 = "56526e";
    #   base08 = "eb6f92";
    #   base09 = "f6c177";
    #   base0A = "ea9a97";
    #   base0B = "3e8fb0";
    #   base0C = "9ccfd8";
    #   base0D = "c4a7e7";
    #   base0E = "f6c177";
    #   base0F = "56526e";
    # };
    polarity = "dark";
    #cursor.package = pkgs.bibata-cursors;
    #cursor.name = "Bibata-Modern-Ice";
    #cursor.size = 32;
    fonts = {
      monospace = {
        package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      serif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      sizes = {
        applications = 12;
        terminal = 15;
        desktop = 11;
        popups = 12;
      };
    };
  };
}
