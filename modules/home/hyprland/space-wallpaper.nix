{
  pkgs,
  lib,
  config,
  ...
}:

let
  monitors = [
    "DP-1"
    "DP-2"
    "DP-3"
  ];
  instance = mon: "space-wallpaper@${mon}.service";

  # Upstream ignores the output scale, so on 2x monitors it renders at half resolution and gets upscaled.
  shaderbg = pkgs.shaderbg.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./shaderbg-hidpi.patch ];
  });

  # Freeze a monitor's shader while its active workspace has a fullscreen window (e.g. a game).
  pauser = pkgs.writeShellScript "space-wallpaper-pauser" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.socat
        pkgs.systemd
        config.wayland.windowManager.hyprland.package
      ]
    }:$PATH

    update() {
      workspaces=$(hyprctl -j workspaces)
      hyprctl -j monitors | jq -r '.[] | "\(.name) \(.activeWorkspace.id)"' | while read -r mon ws; do
        if [ "$(jq --argjson id "$ws" 'any(.[]; .id == $id and .hasfullscreen)' <<<"$workspaces")" = true ]; then
          sig=STOP
        else
          sig=CONT
        fi
        systemctl --user kill --signal="$sig" "space-wallpaper@$mon.service" 2>/dev/null || true
      done
    }

    update
    # Also recheck periodically: a wallpaper instance that restarts behind a fullscreen window
    # starts unpaused, and no Hyprland event fires for that.
    (while sleep 5; do update; done) &
    socat -U -"UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r event; do
      case "$event" in
        fullscreen\>\>* | workspace\>\>* | focusedmon\>\>* | openwindow\>\>* | closewindow\>\>* | movewindow\>\>* | moveworkspace\>\>*)
          update
          ;;
      esac
    done
  '';

  toggle = pkgs.writeShellScriptBin "space-wallpaper-toggle" ''
    if systemctl --user is-active --quiet space-wallpaper.target; then
      systemctl --user stop space-wallpaper.target
    else
      systemctl --user start space-wallpaper.target
    fi
  '';

  # Keep retrying instead of hitting systemd's start limit while the compositor is down.
  resilient = {
    Restart = "always";
    RestartSec = 2;
  };
in
{
  home.packages = [ toggle ];

  systemd.user.targets.space-wallpaper = {
    Unit = {
      Description = "Animated space wallpaper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Wants = map instance monitors ++ [ "space-wallpaper-pauser.service" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services."space-wallpaper@" = {
    Unit = {
      Description = "Animated space wallpaper on %i";
      PartOf = [ "space-wallpaper.target" ];
      After = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = resilient // {
      ExecStart = "${shaderbg}/bin/shaderbg --fps 30 --layer background %i ${./shaders/space.frag}";
    };
  };

  systemd.user.services.space-wallpaper-pauser = {
    Unit = {
      Description = "Pause the space wallpaper behind fullscreen windows";
      PartOf = [ "space-wallpaper.target" ];
      After = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = resilient // {
      ExecStart = "${pauser}";
    };
  };
}
