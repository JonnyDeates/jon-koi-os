{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
       gs = "git status";
       gc = "git checkout";
       yeet = "git push --force-with-lease";
       YEET = "git push --force";
       poosh = "git push";
       yoink = "git pull";
      };
    };
  };
}
