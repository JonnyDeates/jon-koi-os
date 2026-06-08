{ config, pkgs, lib, username, ... }:

let
  pythonWithDeps = pkgs.python312.withPackages (ps: [ ps.aioesphomeapi ]);

  deskControlScript = pkgs.writeScript "desk-control" ''
    #!${pythonWithDeps}/bin/python3
    import sys
    import asyncio
    import aioesphomeapi

    ESP32_HOST = "192.168.1.7"
    ESP32_PORT = 6053
    NOISE_PSK = "PAVmcZTXrMAFIZqH59pCWZTtC+4qJbeN9Oeegym6NyU="

    BUTTONS = {
        "sit": 577793763,
        "stand": 1214700371,
    }

    async def main():
        action = sys.argv[1] if len(sys.argv) > 1 else None
        if action not in BUTTONS:
            print(f"Usage: desk-control [sit|stand]", file=sys.stderr)
            sys.exit(1)

        cli = aioesphomeapi.APIClient(ESP32_HOST, ESP32_PORT, password="", noise_psk=NOISE_PSK)
        try:
            await cli.connect(login=True)
            result = cli.button_command(BUTTONS[action])
            if asyncio.iscoroutine(result):
                await result
            print(f"Sent {action} command to desk")
            await asyncio.sleep(1)
            await cli.disconnect()
        except Exception as e:
            print(f"Failed to send {action} command: {e}", file=sys.stderr)
            sys.exit(1)

    asyncio.run(main())
  '';

  standEnforcerScript = pkgs.writeShellScript "stand-enforcer" ''
    LOCK_FILE="/tmp/stand-enforcer.lock"
    LOG_TAG="stand-enforcer"

    log() {
      echo "[$LOG_TAG] $(date '+%Y-%m-%d %H:%M:%S') $1"
    }

    # Re-entrancy guard
    exec 200>"$LOCK_FILE"
    if ! ${pkgs.util-linux}/bin/flock -n 200; then
      log "Another instance is already running. Exiting."
      exit 0
    fi

    # 50% probability gate (RANDOM % 2 == 0)
    ROLL=$(( RANDOM % 2 ))
    if [ "$ROLL" -ne 0 ]; then
      log "Roll was $ROLL (not 0). Skipping stand enforcement."
      exit 0
    fi
    log "Roll was 0. STAND TIME!"

    # Notification
    ${pkgs.libnotify}/bin/notify-send -u normal -a "Stand Enforcer" \
      "Standing break - 15 minutes"

    # Raise desk via ESP32
    log "Sending STAND command to desk via ESP32..."
    ${deskControlScript} stand || log "WARNING: Failed to send stand command"

    # Wait 15 minutes
    sleep 900

    # Lower desk via ESP32
    log "Sending SIT command to desk via ESP32..."
    ${deskControlScript} sit || log "WARNING: Failed to send sit command"

    ${pkgs.libnotify}/bin/notify-send -u normal -a "Stand Enforcer" \
      "Standing break complete"

    log "Stand enforcement complete."
  '';
in
{
  config = {
    systemd.services.stand-enforcer = {
      description = "Random standing desk enforcement (50% chance per hour)";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        User = "${username}";
        Environment = [
          "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
          "WAYLAND_DISPLAY=wayland-1"
          "XDG_RUNTIME_DIR=/run/user/1000"
        ];
        ExecStart = "${standEnforcerScript}";
        TimeoutStartSec = "1200";
      };
    };

    systemd.timers.stand-enforcer = {
      description = "Hourly trigger for standing desk enforcement";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* *:00:00";
        RandomizedDelaySec = "300";
        Persistent = false;
        Unit = "stand-enforcer.service";
      };
    };
  };
}
