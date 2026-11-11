{ pkgs, config, ... }:

let
  composeDir = "${config.home.homeDirectory}/Documents/Github/infrastructure/Docker Compose";
  notify = "${pkgs.libnotify}/bin/notify-send";

  # Bring a compose project up; with a url, wait until it answers and open it in the browser.
  mkStart =
    {
      name,
      title,
      compose,
      url ? null,
    }:
    pkgs.writeShellScriptBin name (
      ''
        set -e
        docker compose -f "${compose}" up -d
      ''
      + (
        if url == null then
          ''
            ${notify} "${title}" "Started"
          ''
        else
          ''
            ${notify} "${title}" "Starting..."
            for _ in $(seq 180); do
              if ${pkgs.curl}/bin/curl -sf -o /dev/null "${url}"; then
                exec ${pkgs.xdg-utils}/bin/xdg-open "${url}"
              fi
              sleep 1
            done
            ${notify} -u critical "${title}" "Didn't come up after 3 minutes. Check: docker compose -f '${compose}' logs"
            exit 1
          ''
      )
    );

  mkStop =
    {
      name,
      title,
      compose,
    }:
    pkgs.writeShellScriptBin name ''
      docker compose -f "${compose}" down
      ${notify} "${title}" "Stopped"
    '';

  comfyCompose = "${composeDir}/ComfyUI/docker-compose.yaml";
  ollamaCompose = "${composeDir}/Ollama/docker-compose.yaml";

  comfyui = mkStart {
    name = "comfyui";
    title = "ComfyUI";
    compose = comfyCompose;
    url = "http://127.0.0.1:8188";
  };
  comfyui-kill = mkStop {
    name = "comfyui-kill";
    title = "ComfyUI";
    compose = comfyCompose;
  };

  # Ollama, Open WebUI and Chroma share one compose project, so stopping Ollama stops all three.
  open-webui = mkStart {
    name = "open-webui";
    title = "Open WebUI";
    compose = ollamaCompose;
    url = "http://127.0.0.1:3000";
  };
  ollama-start = mkStart {
    name = "ollama-start";
    title = "Ollama";
    compose = ollamaCompose;
  };
  ollama-stop = mkStop {
    name = "ollama-stop";
    title = "Ollama";
    compose = ollamaCompose;
  };
in
{
  home.packages = [
    comfyui
    comfyui-kill
    open-webui
    ollama-start
    ollama-stop
  ];

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
    open-webui = {
      name = "Open WebUI";
      comment = "Start Ollama + Open WebUI (Docker) and open it in the browser";
      exec = "${open-webui}/bin/open-webui";
      icon = "internet-chat";
      categories = [ "Network" ];
    };
    ollama-stop = {
      name = "Stop Ollama";
      comment = "Stop Ollama, Open WebUI and Chroma and free the GPU";
      exec = "${ollama-stop}/bin/ollama-stop";
      icon = "process-stop";
      categories = [ "Network" ];
    };
  };
}
