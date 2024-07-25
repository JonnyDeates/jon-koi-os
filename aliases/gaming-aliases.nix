{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
       steam = "flatpak override --user --filesystem='/run/media/jonkoi/Game Disc' com.valvesoftware.Steam && flatpak run com.valvesoftware.Steam";
      };
    };
  };
}
