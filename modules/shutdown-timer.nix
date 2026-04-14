{ config, pkgs, lib, username, ... }:

{
  config = {
    systemd.services.shutdown-warning = {
      description = "Send shutdown warnings and power off";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        # Run as the user to send notifications to their session
        User = "${username}";
        ExecStart = pkgs.writeShellScriptBin "shutdown-with-warnings" ''
          #!/run/current-system/sw/bin/bash

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
          sleep $(( 60 )) && systemctl poweroff
        '';
      };
    };

    systemd.timers.shutdown-timer = {
      description = "Daily shutdown at 10:30 PM CST";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "22:30:00";
        Persistent = true;
      };
    };
  };
}
