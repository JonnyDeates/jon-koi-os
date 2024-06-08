{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
       gs = "git status";
       yeet = "git push --force";
       poosh = "git push";
       yoink = "git pull";
      };
    };
  };
}
