{ pkgs, config, ... }:

let
  composeFile = "${config.home.homeDirectory}/Documents/Github/infrastructure/Docker Compose/ComfyUI/docker-compose.yaml";
  url = "http://127.0.0.1:8188";

  comfyui = pkgs.writeShellScriptBin "comfyui" ''
    set -e
    docker compose -f "${composeFile}" up -d
    ${pkgs.libnotify}/bin/notify-send -i applications-graphics "ComfyUI" "Starting..."
    for _ in $(seq 120); do
      if ${pkgs.curl}/bin/curl -sf -o /dev/null "${url}"; then
        exec ${pkgs.xdg-utils}/bin/xdg-open "${url}"
      fi
      sleep 1
    done
    ${pkgs.libnotify}/bin/notify-send -u critical "ComfyUI" "Didn't come up after 2 minutes. Check: docker logs comfyui-comfyui-1"
    exit 1
  '';

  comfyui-kill = pkgs.writeShellScriptBin "comfyui-kill" ''
    docker compose -f "${composeFile}" down
    ${pkgs.libnotify}/bin/notify-send -i applications-graphics "ComfyUI" "Stopped"
  '';
in
{
  home.packages = [ comfyui comfyui-kill ];

  xdg.desktopEntries = {
    comfyui = {
      name = "ComfyUI";
      comment = "Start ComfyUI (Docker) and open it in the browser";
      exec = "${comfyui}/bin/comfyui";
      icon = "applications-graphics";
      categories = [ "Graphics" ];
    };
    comfyui-kill = {
      name = "Stop ComfyUI";
      comment = "Stop the ComfyUI container and free the GPU";
      exec = "${comfyui-kill}/bin/comfyui-kill";
      icon = "process-stop";
      categories = [ "Graphics" ];
    };
  };
}
