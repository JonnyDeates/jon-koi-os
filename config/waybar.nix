{
  pkgs,
  lib,
  host,
  config,
  ...
}:

let
  betterTransition = "all 0.3s cubic-bezier(.55,-0.68,.48,1.682)";
  koiColor = "#7bc9ff";
  textColor = "black";
  gammaScript = pkgs.writeShellScriptBin "gamma-toggle" ''
    LOCK_FILE="/tmp/waybar-gamma.lock"
    START_CMD="systemctl --user start gammastep"
    STOP_CMD="systemctl --user stop gammastep"

    toggle() {
      if [ -f "$LOCK_FILE" ]; then
        # Run stop command, silence errors
        $STOP_CMD >/dev/null 2>&1
        rm -f "$LOCK_FILE"
      else
        # Run start command in background, silence errors
        $START_CMD >/dev/null 2>&1 &
        touch "$LOCK_FILE"
      fi
    }

    if [ "$1" == "toggle" ]; then
      toggle
    fi

    # --- STEP 2: GUARANTEED JSON OUTPUT ---
    if [ -f "$LOCK_FILE" ]; then
      echo '{"text": "⛅", "tooltip": "Gamma is ON"}'
    else
      echo '{"text": "🌞", "tooltip": "Gamma is OFF"}'
    fi
  '';
  inherit (import ../hosts/${host}/variables.nix) clock24h;
in
with lib;
{
  # Configure & Theme Waybar
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    settings = [
      {
        layer = "top";
        position = "top";
        modules-center = [ "hyprland/workspaces" ];
        modules-left = [
          "custom/startmenu"
          "hyprland/window"
          "pulseaudio"
          "cpu"
          "memory"
          "custom/gamma_toggle"
          "idle_inhibitor"
        ];
        modules-right = [
          "custom/hyprbindings"
          "custom/notification"
          "custom/exit"
          "battery"
          "tray"
          "clock"
        ];

        "hyprland/workspaces" = {
          format = "{name}";
          format-icons = {
            default = " ";
            active = " ";
            urgent = " ";
          };
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
        };
        "clock" = {
          format = if clock24h == true then '' {:L%H:%M}'' else '' {:L%I:%M %p}'';
          tooltip = true;
          tooltip-format = "<big>{:%A, %d.%B %Y }</big>\n<tt><small>{calendar}</small></tt>";
        };
        "hyprland/window" = {
          max-length = 22;
          separate-outputs = false;
          rewrite = {
            "" = "Idle";
          };
        };
        "memory" = {
          interval = 5;
          format = " {}%";
          tooltip = true;
        };
        "cpu" = {
          interval = 5;
          format = " {usage:2}%";
          tooltip = true;
        };
        "disk" = {
          format = " {free}";
          tooltip = true;
        };
        "network" = {
          format-icons = [
            "󰤯"
            "󰤟"
            "󰤢"
            "󰤥"
            "󰤨"
          ];
          format-ethernet = " {bandwidthDownOctets}";
          format-wifi = "{icon} {signalStrength}%";
          format-disconnected = "󰤮";
          tooltip = false;
        };
        "tray" = {
          spacing = 12;
        };
        "pulseaudio" = {
          format = "{icon} {volume}% {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          format-source = " {volume}%";
          format-source-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [
              ""
              ""
              ""
            ];
          };
          on-click = "sleep 0.1 && pavucontrol";
        };
        "custom/exit" = {
          tooltip = false;
          format = "";
          on-click = "sleep 0.1 && wlogout";
        };
        "custom/startmenu" = {
          tooltip = false;
          format = "🍀";
          # exec = "rofi -show drun";
          on-click = "sleep 0.1 && rofi-launcher";
        };
        "custom/hyprbindings" = {
          tooltip = false;
          format = "❓";
          on-click = "sleep 0.1 && list-hypr-bindings";
        };
        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = {
            activated = "👍";
            deactivated = "👎";
          };
          tooltip = "true";
        };
        "custom/gamma_toggle" = {
        return-type = "json";
        exec = "${gammaScript}/bin/gamma-toggle";
        interval = 1;
        on-click = "${gammaScript}/bin/gamma-toggle toggle";
        format = "{}";
        tooltip = true;
        };
        "custom/notification" = {
          tooltip = false;
          format = "{icon} {}";
          format-icons = {
            notification = "<span foreground='red'><sup>+</sup></span>";
            none = "";
            dnd-notification = "<span foreground='red'><sup>+</sup></span>";
            dnd-none = "";
            inhibited-notification = "<span foreground='red'><sup>+</sup></span>";
            inhibited-none = "";
            dnd-inhibited-notification = "<span foreground='red'><sup>+</sup></span>";
            dnd-inhibited-none = "";
          };
          return-type = "json";
          exec-if = "which swaync-client";
          exec = "swaync-client -swb";
          on-click = "sleep 0.1 && task-waybar";
          escape = true;
        };
        "battery" = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󱘖 {capacity}%";
          format-icons = [
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
          on-click = "";
          tooltip = false;
        };
      }
    ];
    style = concatStrings [
      ''
        * {
          font-family: JetBrainsMono Nerd Font Mono;
          font-size: 16px;
          border-radius: 0px;
          border: none;
          min-height: 0px;
        }
        window#waybar {
          background: rgba(0,0,0,0);
        }
        #workspaces {
          color: ${textColor};
          background: ${koiColor};
          margin: 4px 4px;
          padding: 5px 5px;
          border-radius: 16px;
        }
        #workspaces button {
          font-weight: bold;
          padding: 0px 5px;
          margin: 0px 3px;
          border-radius: 16px;
          color: ${textColor};
          background: white;
          opacity: 0.5;
          transition: ${betterTransition};
        }
        #workspaces button.active {
          font-weight: bold;
          padding: 0px 5px;
          margin: 0px 3px;
          border-radius: 16px;
          color: ${textColor};
          background: linear-gradient(45deg, white, ${koiColor});
          transition: ${betterTransition};
          opacity: 1.0;
          min-width: 40px;
        }
        #workspaces button:hover {
          font-weight: bold;
          border-radius: 16px;
          color: white;
          background: black;
          opacity: 0.8;
          transition: ${betterTransition};
        }
        tooltip {
          background: black;
          border: 1px solid ${koiColor};
          border-radius: 12px;
        }
        tooltip label {
          color: ${koiColor};
        }
        #window, #pulseaudio, #cpu, #memory, #idle_inhibitor, #custom-gamma_toggle {
          font-weight: bold;
          margin: 4px 0px;
          margin-left: 7px;
          padding: 0px 18px;
          color: ${textColor};
          background: ${koiColor};
          border-radius: 8px;
          box-shadow: 1px 1px 1px rgba(0,0,0,0.25);
        }
        #custom-startmenu {
          color: ${textColor};
          background: ${koiColor};
          font-size: 32px;
          margin: 0px;
          padding: 0px 12px;
          border-radius: 0px 0px 16px 0px;
        }
        #custom-hyprbindings, #network, #battery,
        #custom-notification, #tray, #custom-exit {
          font-weight: bold;
          color: ${textColor};
          background: ${koiColor};
          margin: 4px 0px;
          margin-right: 7px;
          border-radius: 8px;
          padding: 0px 18px;
        }
        #clock {
          font-weight: bold;
          color: ${textColor};
          background: ${koiColor};
          margin: 0px;
          padding: 0px 12px;
          border-radius: 0px 0px 0px 16px;
        }
      ''
    ];
  };
}
