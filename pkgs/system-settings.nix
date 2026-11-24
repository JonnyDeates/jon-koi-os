{ pkgs }:
pkgs.writeShellScriptBin "system-settings" ''
    DAY=$(date +%u)
    HOUR=$(date +%-H)

    # "Tonight" — if past midnight but before 2AM, the night started yesterday.
    if [ "$HOUR" -lt 2 ]; then
      NIGHT_DATE=$(date -d "yesterday" +%Y-%m-%d)
      NIGHT_DOW=$(date -d "yesterday" +%u)
      NIGHT_LABEL=$(date -d "yesterday" +%A)
    else
      NIGHT_DATE=$(date +%Y-%m-%d)
      NIGHT_DOW=$DAY
      NIGHT_LABEL=$(date +%A)
    fi

    case "$NIGHT_DOW" in
      4|5|6) TONIGHT_DEADLINE="00:00" ;;
      *)     TONIGHT_DEADLINE="22:00" ;;
    esac

    POSTPONE_FILE="/var/lib/shutdown-timer/postpone-last"
    case "$NIGHT_DOW" in
      4|5|6)
        if [ "$(cat "$POSTPONE_FILE" 2>/dev/null)" = "$NIGHT_DATE" ]; then
          POSTPONE_STATE="Used (shutdown at 01:00)"
          TONIGHT_DEADLINE="01:00"
        else
          POSTPONE_STATE="Available (+1h, to 01:00)"
        fi
        ;;
      *) POSTPONE_STATE="Not available tonight" ;;
    esac

    STEAM_STATE="Free"
    if { [ "$DAY" -le 4 ] && [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 17 ]; } || \
       { [ "$DAY" -eq 5 ] && [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 13 ]; }; then
      if [ "$DAY" -eq 5 ]; then
        STEAM_STATE="Blocked (until 13:00)"
      else
        STEAM_STATE="Blocked (until 17:00)"
      fi
    fi

    DND=$(${pkgs.swaynotificationcenter}/bin/swaync-client -D 2>/dev/null || echo unknown)
    case "$DND" in
      true)  DND_STATE="ON" ;;
      false) DND_STATE="OFF" ;;
      *)     DND_STATE="?" ;;
    esac

    if systemctl --user is-active --quiet hypridle.service; then
      IDLE_STATE="Normal (screen may sleep)"
    else
      IDLE_STATE="Inhibited (screen stays on)"
    fi

    TEXT="━━━ Shutdown Schedule ━━━
    Sun–Wed nights: 22:00
    Thu–Sat nights: 00:00

    Tonight (''${NIGHT_LABEL}): ''${TONIGHT_DEADLINE}
    Postpone (Thu–Sat): ''${POSTPONE_STATE}

  ━━━ Steam Block Schedule ━━━
    Mon–Thu: 06:00 – 17:00
    Fri:     06:00 – 13:00
    Sat–Sun: Free

    Right now: ''${STEAM_STATE}

  ━━━ Notifications ━━━
    Do Not Disturb: ''${DND_STATE}

  ━━━ Idle ━━━
    ''${IDLE_STATE}
  "

    ${pkgs.yad}/bin/yad \
      --title="System Settings" \
      --center --width=520 --fixed \
      --text="''${TEXT}" \
      --text-align=left \
      --button="Postpone Shutdown (1h):200" \
      --button="Toggle DND:202" \
      --button="Open Notification Center:203" \
      --button="Toggle Idle Inhibitor:204" \
      --button="Close:0"

    case $? in
      200) shutdown-postpone ;;
      202) ${pkgs.swaynotificationcenter}/bin/swaync-client -d ;;
      203) ${pkgs.swaynotificationcenter}/bin/swaync-client -t ;;
      204)
        if systemctl --user is-active --quiet hypridle.service; then
          systemctl --user stop hypridle.service
        else
          systemctl --user start hypridle.service
        fi
        ;;
    esac
''
