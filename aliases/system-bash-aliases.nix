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
       restartDeskThing = "systemctl --user restart deskThingService";
       restartWaybar = "(pidof waybar | xargs kill) && systemctl --user enable --now waybar.service";
       #sv = "sudo nvim";
       gcCleanup = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
       #v = "nvim";
       #cat = "bat";
       ls = "eza --icons";
       ll = "eza -lh --icons --grid --group-directories-first";
       la = "eza -lah --icons --grid --group-directories-first";
       ".." = "cd ..";
      };

    };
  };
}
