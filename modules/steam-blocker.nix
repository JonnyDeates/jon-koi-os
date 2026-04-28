{ config, pkgs, lib, username, ... }:

let
  steamBlockScript = pkgs.writeShellScript "steam-blocker" ''
    DAY=$(date +%u)   # 1=Mon..5=Fri, 6=Sat, 7=Sun
    HOUR=$(date +%-H)

    # Only enforce on weekdays (Mon-Fri), 6 AM to 6 PM
    if [ "$DAY" -le 5 ] && [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then
      # Kill flatpak steam
      ${pkgs.flatpak}/bin/flatpak kill com.valvesoftware.Steam 2>/dev/null || true

      # Kill native steam processes
      ${pkgs.procps}/bin/pkill -f "steamwebhelper" 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "/steam" 2>/dev/null || true
    fi
  '';
in
{
  config = {
    systemd.services.steam-blocker = {
      description = "Kill Steam during weekday work hours";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStart = "${steamBlockScript}";
      };
    };

    systemd.timers.steam-blocker = {
      description = "Enforce Steam block on weekdays 6AM-6PM";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 06..17:00/5:00";
        Persistent = false;
        Unit = "steam-blocker.service";
      };
    };
  };
}
