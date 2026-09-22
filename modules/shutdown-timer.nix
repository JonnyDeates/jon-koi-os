{ config, pkgs, lib, username, ... }:

let
  keyFile = "/var/lib/shutdown-timer/hmac.key";

  shutdownCheckScript = pkgs.writeShellScript "shutdown-check" ''
    LOG_TAG="shutdown-check"
    MODE="''${1:-warn}"  # "warn" (notify on arm) or "silent" (guard re-arm)

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
    # Thursday (4), Friday (5) and Saturday (6) nights: midnight
    # All other nights: 22:30
    if [ "$DOW" -eq 4 ] || [ "$DOW" -eq 5 ] || [ "$DOW" -eq 6 ]; then
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

    log "MODE=$MODE DOW=$DOW HOUR=$HOUR DEADLINE=$(date -d @$DEADLINE '+%Y-%m-%d %H:%M') NOW=$(date '+%H:%M')"

    # Not past deadline yet — exit
    if [ "$NOW" -lt "$DEADLINE" ]; then
      log "Not past deadline yet. Exiting."
      exit 0
    fi

    # Check snooze (HMAC-signed to prevent bare `echo N > /tmp/...` bypass)
    SNOOZE_FILE="/tmp/shutdown-snooze-''${NIGHT_DATE}"
    KEY_FILE="${keyFile}"
    if [ -f "$SNOOZE_FILE" ]; then
      SNOOZE_LINE=$(cat "$SNOOZE_FILE")
      SNOOZE_UNTIL="''${SNOOZE_LINE%|*}"
      SNOOZE_HMAC="''${SNOOZE_LINE#*|}"
      if [ -z "$SNOOZE_UNTIL" ] || [ -z "$SNOOZE_HMAC" ] || [ "$SNOOZE_UNTIL" = "$SNOOZE_LINE" ]; then
        log "Snooze file malformed (missing HMAC). Ignoring."
      elif [ ! -r "$KEY_FILE" ]; then
        log "HMAC key unreadable at $KEY_FILE. Ignoring snooze."
      else
        EXPECTED_HMAC=$(printf '%s' "$SNOOZE_UNTIL" | ${pkgs.openssl}/bin/openssl dgst -sha256 -hmac "$(cat "$KEY_FILE")" | awk '{print $NF}')
        if [ "$SNOOZE_HMAC" != "$EXPECTED_HMAC" ]; then
          log "Snooze file HMAC mismatch. Ignoring."
        elif [ "$NOW" -lt "$SNOOZE_UNTIL" ]; then
          log "Snoozed until $(date -d @''${SNOOZE_UNTIL} '+%H:%M'). Skipping."
          exit 0
        else
          log "Snooze expired. Proceeding with shutdown."
        fi
      fi
    fi

    # If a shutdown is already scheduled, don't re-arm or re-notify.
    if [ -f /run/systemd/shutdown/scheduled ]; then
      log "Shutdown already scheduled. Nothing to do."
      exit 0
    fi

    # Past deadline, no valid snooze, no pending shutdown — schedule one.
    # `shutdown -h +5` is queued by systemd-logind and survives
    # `systemctl stop` on this service. Cancelling requires `sudo shutdown -c`.
    log "Past shutdown deadline. Scheduling shutdown in 5 minutes ($MODE)."
    if [ "$MODE" = "warn" ]; then
      warn 5
    else
      # Guard re-arm after a cancellation — notify so user knows escape failed.
      ${pkgs.libnotify}/bin/notify-send -u critical -a "System Shutdown" \
        "Shutdown re-armed. Cancellation ignored — go to bed."
    fi
    shutdown -h +5 "Nightly shutdown enforcement — go to bed"
  '';
in
{
  config = {
    # Layer 4: HMAC key for signing snooze files. Generated once at boot,
    # readable only by the target user (root can still read, obviously).
    systemd.services.shutdown-timer-init = {
      description = "Initialize shutdown-timer HMAC key";
      wantedBy = [ "multi-user.target" ];
      before = [ "shutdown-check.service" "shutdown-guard.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -d -m 0755 /var/lib/shutdown-timer
        if [ ! -s ${keyFile} ]; then
          ${pkgs.openssl}/bin/openssl rand -hex 32 > ${keyFile}
        fi
        chown ${username} ${keyFile}
        chmod 0400 ${keyFile}
      '';
    };

    systemd.services.shutdown-check = {
      description = "Check if past nightly shutdown deadline and power off";
      requires = [ "shutdown-timer-init.service" ];
      after = [ "shutdown-timer-init.service" ];
      # Layer 1: refuse `systemctl stop shutdown-check.service`.
      unitConfig.RefuseManualStop = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        User = "${username}";
        Environment = [
          "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
          "WAYLAND_DISPLAY=wayland-1"
          "XDG_RUNTIME_DIR=/run/user/1000"
        ];
        ExecStart = "${shutdownCheckScript} warn";
        TimeoutStartSec = "600";
      };
    };

    systemd.timers.shutdown-timer = {
      description = "Nightly shutdown enforcement (every 15 min, 10PM-2AM)";
      wantedBy = [ "timers.target" ];
      # Layer 1: refuse `systemctl stop shutdown-timer.timer`.
      unitConfig.RefuseManualStop = true;
      timerConfig = {
        OnCalendar = "*-*-* 22,23,00,01:00,15,30,45:00";
        Persistent = false;
        Unit = "shutdown-check.service";
      };
    };

    # Layer 2: independent watchdog. Fires every minute during the enforcement
    # window. If a shutdown was cancelled (`shutdown -c`) or the primary
    # check service was killed mid-arm, this re-schedules within 60s.
    # To defeat: user must stop BOTH timers AND cancel — three separate
    # commands, all against RefuseManualStop units.
    systemd.services.shutdown-guard = {
      description = "Re-arm nightly shutdown if it was cancelled";
      requires = [ "shutdown-timer-init.service" ];
      after = [ "shutdown-timer-init.service" ];
      unitConfig.RefuseManualStop = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        User = "${username}";
        Environment = [
          "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
          "WAYLAND_DISPLAY=wayland-1"
          "XDG_RUNTIME_DIR=/run/user/1000"
        ];
        ExecStart = "${shutdownCheckScript} silent";
        TimeoutStartSec = "60";
      };
    };

    systemd.timers.shutdown-guard = {
      description = "Watchdog: re-arm nightly shutdown every minute, 10PM-2AM";
      wantedBy = [ "timers.target" ];
      unitConfig.RefuseManualStop = true;
      timerConfig = {
        OnCalendar = [
          "*-*-* 22..23:*:00"
          "*-*-* 00..01:*:00"
        ];
        Persistent = false;
        Unit = "shutdown-guard.service";
      };
    };
  };
}
