{ config, pkgs, lib, username, ... }:

let
  gameBlockScript = pkgs.writeShellScript "steam-blocker" ''
    DAY=$(date +%u)   # 1=Mon..5=Fri, 6=Sat, 7=Sun
    HOUR=$(date +%-H)

    # Only enforce on weekdays (Mon-Fri), 6 AM to 5 PM
    if [ "$DAY" -le 5 ] && [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 17 ]; then
      # Steam (flatpak + native)
      ${pkgs.flatpak}/bin/flatpak kill com.valvesoftware.Steam 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "steamwebhelper" 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "/steam" 2>/dev/null || true

      # r2modman (Electron; -f catches renderer/child processes)
      ${pkgs.procps}/bin/pkill -fi "r2modman" 2>/dev/null || true

      # Prism Launcher (matches both `prismlauncher` and `PrismLauncher`)
      ${pkgs.procps}/bin/pkill -fi "prismlauncher" 2>/dev/null || true

      # Minecraft — target the Java main class + Prism's launcher class
      # so we don't nuke unrelated Java processes.
      ${pkgs.procps}/bin/pkill -f "net.minecraft" 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -f "minecraft.launcher" 2>/dev/null || true
    fi
  '';
in
{
  config = {
    systemd.services.steam-blocker = {
      description = "Kill Steam and other game launchers during weekday work hours";
      # Layer 1: refuse `systemctl stop steam-blocker.service`.
      unitConfig.RefuseManualStop = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStart = "${gameBlockScript}";
      };
    };

    systemd.timers.steam-blocker = {
      description = "Enforce game blocker on weekdays 6AM-5PM (every 5 min)";
      wantedBy = [ "timers.target" ];
      # Layer 1: refuse `systemctl stop steam-blocker.timer`.
      unitConfig.RefuseManualStop = true;
      timerConfig = {
        OnCalendar = "*-*-* 06..16:00/5:00";
        Persistent = false;
        Unit = "steam-blocker.service";
      };
    };

    # Layer 2: independent watchdog. Fires every minute during the
    # enforcement window and runs the same kill script. If the primary
    # timer is masked, this still culls launched games within 60s.
    # To defeat: user must mask BOTH timers — two separate commands
    # against RefuseManualStop units.
    systemd.services.steam-guard = {
      description = "Watchdog: kill game launchers if primary blocker was defeated";
      unitConfig.RefuseManualStop = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStart = "${gameBlockScript}";
      };
    };

    systemd.timers.steam-guard = {
      description = "Watchdog: run game blocker every minute during work hours";
      wantedBy = [ "timers.target" ];
      unitConfig.RefuseManualStop = true;
      timerConfig = {
        OnCalendar = "*-*-* 06..16:*:00";
        Persistent = false;
        Unit = "steam-guard.service";
      };
    };
  };
}
