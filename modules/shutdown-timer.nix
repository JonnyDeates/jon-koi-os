{ config, pkgs, lib, username, ... }:

let
  shutdownScript = pkgs.writeShellScript "shutdown-with-warnings" ''
    warn() {
      local mins=$1
      ${pkgs.libnotify}/bin/notify-send -u critical -a "System Shutdown" \
        "Computer will shut down in $mins minute(s)."
    }

    # Send warnings at each interval, then shutdown
    sleep $(( 30 * 60 )) && warn 30
    sleep $(( 15 * 60 )) && warn 15
    sleep $(( 10 * 60 )) && warn 5
    sleep $(( 2 * 60 )) && warn 3
    sleep $(( 2 * 60 )) && warn 1
    sleep 60 && systemctl poweroff
  '';
in
{
  config = {
    systemd.services.shutdown-warning = {
      description = "Send shutdown warnings and power off";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        User = "${username}";
        Environment = "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus";
        ExecStart = "${shutdownScript}";
      };
    };

    systemd.timers.shutdown-timer = {
      description = "Daily shutdown at 10:30 PM CT";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "22:30:00";
        Persistent = true;
        Unit = "shutdown-warning.service";
      };
    };
  };
}
