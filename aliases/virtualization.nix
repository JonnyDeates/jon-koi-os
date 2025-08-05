{ config, pkgs, lib, ...}:
{
  programs = {
    command-not-found.enable = false;

    bash = {
      shellAliases = {
        k = "kubectl";
        h = "helm";
        ytMP4 = "docker run --rm -i -e PGID=$(id -g) -e PUID=$(id -u) -v ~/Videos:/workdir:rw ghcr.io/mikenye/docker-youtube-dl:latest -t mp4 -k ";
        ytMP3 = "docker run --rm -i -e PGID=$(id -g) -e PUID=$(id -u) -v ~/Music:/workdir:rw ghcr.io/mikenye/docker-youtube-dl:latest -t mp3 -k ";
      };
    };
  };
}
