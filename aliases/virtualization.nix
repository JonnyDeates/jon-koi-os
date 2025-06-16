{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
        k = "kubectl";
        h = "helm";
#        yt-dl = "docker run --rm -i -e PGID=$(id -g)  -e PUID=$(id -u) -v "$(pwd)":/workdir:rw ghcr.io/mikenye/docker-youtube-dl:latest'
      };
    };
  };
}
