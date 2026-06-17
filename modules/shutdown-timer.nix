{ config, pkgs, lib, username, ... }:

let
  shutdownCheckScript = pkgs.writeShellScript "shutdown-check" ''
    LOG_TAG="shutdown-check"

    log() {
      echo "[$LOG_TAG] $(date '+%Y-%m-%d %H:%M:%S') $1"
    }

    warn() {
      local mins=$1
      ${pkgs.libnotify}/bin/notify-send -u critical -a "System Shutdown" \
        "Computer will shut down in $mins minute(s)."
    }

    HOUR=$(date +%-H)
    NOW=$(date +%s)

    # Determine which "night" we're in
    if [ "$HOUR" -lt 2 ]; then
      # Past midnight — this night started yesterday
      DOW=$(date -d "yesterday" +%u)
      NIGHT_DATE=$(date -d "yesterday" +%Y-%m-%d)
    else
      DOW=$(date +%u)
      NIGHT_DATE=$(date +%Y-%m-%d)
    fi

    # Determine deadline (epoch seconds)
    # Friday (5) and Saturday (6) nights: midnight
    # All other nights: 22:30
    if [ "$DOW" -eq 5 ] || [ "$DOW" -eq 6 ]; then
      if [ "$HOUR" -ge 22 ]; then
        DEADLINE=$(date -d "tomorrow 00:00" +%s)
      else
        DEADLINE=$(date -d "today 00:00" +%s)
      fi
    else
      if [ "$HOUR" -ge 22 ]; then
        DEADLINE=$(date -d "today 22:30" +%s)
      else
        DEADLINE=$(date -d "yesterday 22:30" +%s)
      fi
    fi

    log "DOW=$DOW HOUR=$HOUR DEADLINE=$(date -d @$DEADLINE '+%Y-%m-%d %H:%M') NOW=$(date '+%H:%M')"

    # Not past deadline yet — exit
    if [ "$NOW" -lt "$DEADLINE" ]; then
      log "Not past deadline yet. Exiting."
      exit 0
    fi

    # Check snooze
    SNOOZE_FILE="/tmp/shutdown-snooze-''${NIGHT_DATE}"
    if [ -f "$SNOOZE_FILE" ]; then
      SNOOZE_UNTIL=$(cat "$SNOOZE_FILE")
      if [ "$NOW" -lt "$SNOOZE_UNTIL" ]; then
        log "Snoozed until $(date -d @''${SNOOZE_UNTIL} '+%H:%M'). Skipping."
        exit 0
      else
        log "Snooze expired. Proceeding with shutdown."
      fi
    fi

    # Past deadline and no active snooze — shut down
    log "Past shutdown deadline. Warning and shutting down."
    warn 5
    sleep 240
    warn 1
    sleep 60
    log "Shutting down NOW."
    systemctl poweroff
  '';
in
{
  config = {
    systemd.services.shutdown-check = {
      description = "Check if past nightly shutdown deadline and power off";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        User = "${username}";
        Environment = [
          "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
          "WAYLAND_DISPLAY=wayland-1"
          "XDG_RUNTIME_DIR=/run/user/1000"
        ];
        ExecStart = "${shutdownCheckScript}";
        TimeoutStartSec = "600";
      };
    };

    systemd.timers.shutdown-timer = {
      description = "Nightly shutdown enforcement (every 15 min, 10PM-2AM)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 22,23,00,01:00,15,30,45:00";
        Persistent = false;
        Unit = "shutdown-check.service";
      };
    };
  };
}
