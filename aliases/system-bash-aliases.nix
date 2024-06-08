{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
       build-os = "sudo nixos-rebuild switch --flake /home/jonkoi/jon-koi-os#default";
       upgrade-os = "nix flake update /home/jonkoi/jon-koi-os";
       trash-os = "sudo nixos-collect-garbage --delete-older-than 14d";
      };
    };
  };
}
