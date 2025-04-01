{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
        k = "kubectl";
        h = "helm";
      };
    };
  };
}
