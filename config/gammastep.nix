{ pkgs, lib, username, ... }:

let
  configPath = "/home/${username}/.config/gammastep/config_mutable.ini";

  # --- THE GUI SCRIPT ---
  gammaGui = pkgs.writeShellScriptBin "gamma-gui" ''
      #!${pkgs.bash}/bin/bash

      CONFIG_FILE="${configPath}"

      # 1. Read Status
      if systemctl --user is-active --quiet gammastep; then
          CUR_ENABLED="TRUE"
      else
          CUR_ENABLED="FALSE"
      fi

      # Defaults
      DEF_TEMP=2500
      DEF_BRIGHT=0.7
      DEF_DAWN="06:00-07:00"
      DEF_DUSK="18:00-20:00"

      # Read existing values
      if [ -f "$CONFIG_FILE" ]; then
          CUR_TEMP=$(grep "temp-night" $CONFIG_FILE | cut -d'=' -f2)
          CUR_BRIGHT=$(grep "brightness-night" $CONFIG_FILE | cut -d'=' -f2)
          CUR_DAWN=$(grep "dawn-time" $CONFIG_FILE | cut -d'=' -f2)
          CUR_DUSK=$(grep "dusk-time" $CONFIG_FILE | cut -d'=' -f2)
      fi

      : ''${CUR_TEMP:=$DEF_TEMP}
      : ''${CUR_BRIGHT:=$DEF_BRIGHT}
      : ''${CUR_DAWN:=$DEF_DAWN}
      : ''${CUR_DUSK:=$DEF_DUSK}

      # 2. Launch YAD GUI
      # We use NUM (Numeric) fields with explicit ranges: VAL!MIN..MAX!STEP(!PRECISION)
      OUTPUT=$(${pkgs.yad}/bin/yad --title="Gammastep Control" \
          --window-icon="preferences-system" \
          --center --width=350 --fixed \
          --form \
          --field="Enable Service:CHK" "$CUR_ENABLED" \
          --field="Night Temp (K):NUM" "$CUR_TEMP!1000..25000!50" \
          --field="Night Brightness:NUM" "$CUR_BRIGHT!0.1..1.0!0.05!2" \
          --field="Dawn Time (HH:MM-HH:MM):TXT" "$CUR_DAWN" \
          --field="Dusk Time (HH:MM-HH:MM):TXT" "$CUR_DUSK" \
          --button="Cancel:1" \
          --button="Save:0")

      EXIT_CODE=$?

      if [ $EXIT_CODE -ne 0 ]; then
          exit 0
      fi

      # Read output
      IFS='|' read -r ENABLED NEW_TEMP NEW_BRIGHT NEW_DAWN NEW_DUSK JUNK <<< "$OUTPUT"

      # 3. SANITY CHECK (The fix for the crash)
      # Ensure NEW_TEMP is an integer and at least 1000
      NEW_TEMP=''${NEW_TEMP%.*} # Remove decimals if any
      if [ -z "$NEW_TEMP" ] || [ "$NEW_TEMP" -lt 1000 ]; then
          NEW_TEMP=1000
      fi

      # 4. Write Config
      mkdir -p $(dirname "$CONFIG_FILE")
      cat > "$CONFIG_FILE" <<EOF
  [general]
  temp-day=6500
  temp-night=$NEW_TEMP
  brightness-day=1.0
  brightness-night=$NEW_BRIGHT
  gamma-day=1.0
  gamma-night=1.0
  dawn-time=$NEW_DAWN
  dusk-time=$NEW_DUSK
  adjustment-method=wayland
  location-provider=manual

  [manual]
  lat=30.633
  lon=97.678
  EOF

      # 5. Apply State
      if [ "$ENABLED" == "TRUE" ]; then
          systemctl --user stop gammastep
          systemctl --user start gammastep

          sleep 0.5
          if systemctl --user is-active --quiet gammastep; then
               ${pkgs.libnotify}/bin/notify-send "Gammastep" "Active: ''${NEW_TEMP}K" -i weather-clear-night
          else
               ${pkgs.libnotify}/bin/notify-send "Gammastep" "Failed! Check logs." -i dialog-error
          fi
      else
          systemctl --user stop gammastep
          ${pkgs.libnotify}/bin/notify-send "Gammastep" "Service Stopped" -i weather-clear
      fi
    '';

  # --- THE START SCRIPT ---
  # Only creates default config if missing, does NOT launch GUI (prevents hanging)
  gammastartScript = pkgs.writeShellScriptBin "gammastart" ''
    if [ ! -f "${configPath}" ]; then
      mkdir -p $(dirname "${configPath}")
      echo "[general]" > "${configPath}"
      echo "temp-night=2500" >> "${configPath}"
      echo "brightness-night=0.7" >> "${configPath}"
      echo "location-provider=manual" >> "${configPath}"
      echo "adjustment-method=wayland" >> "${configPath}"
      echo "[manual]" >> "${configPath}"
      echo "lat=30.633" >> "${configPath}"
      echo "lon=97.678" >> "${configPath}"
    fi
    ${pkgs.gammastep}/bin/gammastep -c ${configPath}
  '';

in
{
  home.packages = with pkgs; [
    gammastep
    yad
    libnotify
    gammaGui
  ];

  services.gammastep.enable = false;

  systemd.user.services.gammastep = {
    Unit = {
      Description = "Gammastep (Mutable GUI)";
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${gammastartScript}/bin/gammastart";
      Restart = "on-failure";
      RestartSec = "5s"; # Don't spam restart if config is bad
      # Removed DISPLAY env var; usually not needed for pure Wayland and can confuse gammastep
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
