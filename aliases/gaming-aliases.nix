{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
       steam = "~/.local/bin/steam";
      };
    };
  };
}
