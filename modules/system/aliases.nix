{ username, ... }:

{
  programs.command-not-found.enable = false;

  programs.bash.shellAliases = {
    # System
    build-os = "nixos-rebuild-guard switch --flake /home/${username}/jon-koi-os#default";
    upgrade-os = "nix flake update --flake ~/jon-koi-os/flake.nix";
    gcCleanup = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
    zed = "zed-open";
    gammastop = "systemctl --user stop gammastep";
    gammastart = "systemctl --user start gammastep";
    restartDeskThing = "systemctl --user restart deskThingService";
    restartWaybar = "systemctl --user reset-failed waybar.service; systemctl --user restart waybar.service";
    idlestart = "systemctl --user enable --now hypridle.service";
    idlestop = "systemctl --user disable --now hypridle.service";
    pythonShell = "nix-shell ~/jon-koi-os/shells/python/python3.nix";
    pythonAIShell = "nix-shell ~/jon-koi-os/shells/python/pythonAI.nix";
    pythonAIAudioShell = "nix-shell ~/jon-koi-os/shells/python/pythonAISound.nix";
    ls = "eza --icons";
    ll = "eza -lh --icons --grid --group-directories-first";
    la = "eza -lah --icons --grid --group-directories-first";
    ".." = "cd ..";

    # Git
    gs = "git status";
    gc = "git checkout";
    yeet = "git push --force-with-lease";
    YEET = "git push --force";
    poosh = "git push";
    yoink = "git pull";

    # Quitting things
    kill-steam = "kill -9 $(pgrep -i Steam)";
    kill-gamma = "kill $(pidof gammastep)";

    # Gaming
    steam = "~/.local/bin/steam";

    # Containers
    k = "kubectl";
    h = "helm";
    ytMP4 = "docker run --rm -i -e PGID=$(id -g) -e PUID=$(id -u) -v ~/Videos:/workdir:rw ghcr.io/mikenye/docker-youtube-dl:latest -t mp4 -k ";
    ytMP3 = "docker run --rm -i -e PGID=$(id -g) -e PUID=$(id -u) -v ~/Music:/workdir:rw ghcr.io/mikenye/docker-youtube-dl:latest -t mp3 -k ";
  };
}
