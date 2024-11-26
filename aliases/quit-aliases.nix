{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
       kill-idea = "kill $(ps aux | grep 'java' | awek '{print $2}')";
       kill-steam = "killall steam";
       kill-gamma = "kill $(pidof gammastep)";
      };
    };
  };
}
