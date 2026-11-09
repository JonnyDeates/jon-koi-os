{ pkgs }:

# Reports whether we are inside the shutdown-enforcement window
# [deadline - 1h, deadline + 2h]. Used by nixos-rebuild-guard to block
# flake rebuilds that would otherwise be used to disarm the shutdown units.
#
# Deadline rules mirror modules/shutdown-timer.nix (authoritative source):
#   Thu/Fri/Sat nights: 00:00 the next day
#   Sun/Mon/Tue/Wed  : 22:30 that night
#
# Modes:
#   (no args)         exit 1 if inside the window, exit 0 otherwise
#   --status          print a one-line status (BLOCKED/OK + mins + time)
#   --next-unlock     print the time when the current window ends, or "now"

pkgs.writeShellScriptBin "discipline-window-check" ''
  PRE_WINDOW=$((60 * 60))        # 1 hour before deadline
  POST_WINDOW=$((2 * 60 * 60))   # 2 hours after deadline

  compute_deadline() {
    # $1 = GNU date relative day ("yesterday" / "today" / "tomorrow")
    local day=$1
    local dow
    dow=$(date -d "$day" +%u)
    if [ "$dow" -ge 4 ] && [ "$dow" -le 6 ]; then
      date -d "$day +1 day 00:00" +%s
    else
      date -d "$day 22:30" +%s
    fi
  }

  NOW=$(date +%s)
  Y_D=$(compute_deadline "yesterday")
  T_D=$(compute_deadline "today")
  M_D=$(compute_deadline "tomorrow")

  check_window() {
    local d=$1
    [ "$NOW" -ge $((d - PRE_WINDOW)) ] && [ "$NOW" -le $((d + POST_WINDOW)) ]
  }

  IN_WINDOW=0
  DEADLINE=
  for d in "$Y_D" "$T_D" "$M_D"; do
    if check_window "$d"; then
      IN_WINDOW=1
      DEADLINE=$d
      break
    fi
  done

  if [ "$IN_WINDOW" -eq 0 ]; then
    for d in "$Y_D" "$T_D" "$M_D"; do
      if [ "$d" -gt "$NOW" ]; then
        DEADLINE=$d
        break
      fi
    done
  fi

  case "''${1:-}" in
    --status)
      if [ "$IN_WINDOW" -eq 1 ]; then
        if [ "$NOW" -lt "$DEADLINE" ]; then
          REMAIN=$(( (DEADLINE - NOW + 59) / 60 ))
          echo "BLOCKED shutdown in ''${REMAIN} min at $(date -d @$DEADLINE '+%H:%M')"
        else
          OVER=$(( (NOW - DEADLINE + 59) / 60 ))
          echo "BLOCKED ''${OVER} min past deadline $(date -d @$DEADLINE '+%H:%M')"
        fi
      else
        REMAIN=$(( (DEADLINE - NOW + 59) / 60 ))
        echo "OK next deadline in ''${REMAIN} min at $(date -d @$DEADLINE '+%a %H:%M')"
      fi
      exit 0
      ;;
    --next-unlock)
      if [ "$IN_WINDOW" -eq 1 ]; then
        UNLOCK=$((DEADLINE + POST_WINDOW))
        date -d "@$UNLOCK" '+%a %H:%M'
      else
        echo "now"
      fi
      exit 0
      ;;
  esac

  if [ "$IN_WINDOW" -eq 1 ]; then
    exit 1
  fi
  exit 0
''
