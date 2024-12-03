{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
       build-os = "sudo nixos-rebuild switch --flake /home/jonkoi/jon-koi-os#default";
       upgrade-os = "nix flake update --flake ~/jon-koi-os/flake.nix";

       gammastop = "systemctl --user stop gammastep";
       gammastart = "systemctl --user start gammastep";
       restartDeskThing = "system --user restart deskThingService";
      };
    };
  };
}
