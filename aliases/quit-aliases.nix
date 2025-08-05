{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
       kill-idea = "kill $(ps aux | grep 'java' | awek '{print $2}')";
       kill-steam = "kill -9 $(pgrep -i Steam)";
       kill-gamma = "kill $(pidof gammastep)";
      };
    };
  };
}
