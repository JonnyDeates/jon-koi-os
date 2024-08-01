{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
       steam = "flatpak override --user --filesystem='/mnt/game_disc' --filesystem='/home/jonkoi/Documents/r2modman' com.valvesoftware.Steam && flatpak run com.valvesoftware.Steam";
      };
    };
  };
}
