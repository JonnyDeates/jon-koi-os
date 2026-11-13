{
  pkgs,
  lib,
  config,
  ...
}:

let
  monitors = [
    "DP-1"
    "DP-2"
    "DP-3"
  ];
  instance = mon: "space-wallpaper@${mon}.service";

  # Upstream ignores the output scale, so on 2x monitors it renders at half resolution and gets upscaled.
  shaderbg = pkgs.shaderbg.overrideAttrs (old: {
    # Plus SHADERBG_EPOCH, so a scene swapped in by a new process carries on the same clock.
    patches = (old.patches or [ ]) ++ [
      ./shaderbg-hidpi.patch
      ./shaderbg-epoch.patch
    ];
  });

  # GLSL needs definitions before use, so the parts are joined in dependency order.
  spaceShader = pkgs.concatText "space.frag" [
    ./shaders/common.glsl
    ./shaders/stars.glsl
    ./shaders/skies/nebula.glsl
    ./shaders/skies/milkyway.glsl
    ./shaders/skies/deepfield.glsl
    ./shaders/skies/cirrus.glsl
    ./shaders/sky.glsl
    ./shaders/bodies.glsl
    ./shaders/events/solar-system.glsl
    ./shaders/events/comet.glsl
    ./shaders/events/black-hole.glsl
    ./shaders/events/galaxy.glsl
    ./shaders/events/pillars.glsl
    ./shaders/events/ring-nebula.glsl
    ./shaders/events/crab.glsl
    ./shaders/events/bipolar.glsl
    ./shaders/events/comet-closeup.glsl
    ./shaders/events/binary.glsl
    ./shaders/events/pulsar.glsl
    ./shaders/events/supernova.glsl
    ./shaders/events/star-surface.glsl
    ./shaders/events/galaxy-collision.glsl
    ./shaders/events/quasar.glsl
    ./shaders/events/rogue.glsl
    ./shaders/events/horizon.glsl
    ./shaders/events/cluster.glsl
    ./shaders/events/giant.glsl
    ./shaders/events/planet.glsl
    ./shaders/events/asteroid-field.glsl
    ./shaders/events/moon.glsl
    ./shaders/events/ringplane.glsl
    ./shaders/events/nebulae/field.glsl
    ./shaders/events/nebulae/cliffs.glsl
    ./shaders/events/nebulae/orion.glsl
    ./shaders/events/nebulae/lagoon.glsl
    ./shaders/events/nebulae/rosette.glsl
    ./shaders/events/nebulae/horsehead.glsl
    ./shaders/events/nebulae/tarantula.glsl
    ./shaders/events/nebulae/veil.glsl
    ./shaders/events/nebulae/rho.glsl
    ./shaders/events/nebulae/forge.glsl
    ./shaders/meteors.glsl
    ./shaders/events/shower.glsl
    ./shaders/main.glsl
  ];

  # Seeds are whole numbers 0-99999 (the shader gets seed / 100). Uses $seed if set, otherwise a
  # random one, and prints it so a scene you like can be brought back.
  pickSeed = ''
    if [ -n "$seed" ]; then
      case "$seed" in
        *[!0-9]*)
          echo "seed must be a whole number" >&2
          exit 1
          ;;
      esac
      seed=$((10#$seed % 100000))
    else
      seed=$(( $(${pkgs.coreutils}/bin/od -An -N4 -tu4 /dev/urandom) % 100000 ))
    fi
    echo "seed: $seed"
  '';
  # Event ids, odds and names, read from the shader at build time: pickEvent pairs each *_CHANCE
  # with an EV_*, and the name is the EV_ name in lower case. One "id weight name" line per scene,
  # plus "plain <share>". The launcher rolls from it and the preview looks names up in it.
  eventTable = pkgs.runCommand "space-wallpaper-events" { } ''
    ${pkgs.gawk}/bin/awk '
      /^const int EV_[A-Z]+ = [0-9]+;/ { n = $3; sub(/^EV_/, "", n); v = $5; sub(/;/, "", v); id[n] = v }
      /^const float [A-Z]+_CHANCE = / { w = $5; sub(/;/, "", w); ch[$3] = w }
      /^const float PLAIN_SKY_SHARE = / { p = $5; sub(/;/, "", p); print "plain", p }
      /^int pickEvent/ { inPick = 1 }
      inPick && /_CHANCE;/ { match($0, /[A-Z]+_CHANCE/); last = substr($0, RSTART, RLENGTH) }
      inPick && /return EV_/ && last != "" { match($0, /EV_[A-Z]+/); e = substr($0, RSTART + 3, RLENGTH - 3); print id[e], ch[last], tolower(e); last = "" }
      inPick && /^}/ { inPick = 0 }
    ' ${spaceShader} > $out
  '';

  seedSed = "s|const float RANDOM_SEED = 0.0;|const float RANDOM_SEED = $seed.0 / 100.0;|";

  # Runs the wallpaper on one output with this launch's seed ($SPACE_WALLPAPER_SEED, or random).
  # One shader holding every scene takes the GPU driver 20+ seconds to compile, so each 30-minute
  # scene runs as its own shader with just that scene compiled in (a few seconds). This script picks
  # each scene, and near the end of a slot - during its plain-sky gap - starts the next scene's
  # shader, then stops the old one once the new one is drawing. All of them share one clock
  # (SHADERBG_EPOCH), so the sky carries on seamlessly across the swap.
  launch = pkgs.writeShellScript "space-wallpaper-launch" ''
    output=$1
    seed=''${SPACE_WALLPAPER_SEED:-}
    ${pickSeed}
    dir="$XDG_RUNTIME_DIR/space-wallpaper"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    base="$dir/$output.frag"
    # One clock for every scene's shader. The sky changes at local midnight: tell the shader today's
    # date (as a day number) and how far into the day the clock starts.
    export SHADERBG_EPOCH=''${EPOCHREALTIME%.*}
    midnight=$(${pkgs.coreutils}/bin/date -d "$(${pkgs.coreutils}/bin/date -d @$SHADERBG_EPOCH +%F)" +%s)
    ${pkgs.gnused}/bin/sed -e "${seedSed}" \
      -e "s/const float SKY_DAY = 0.0;/const float SKY_DAY = $(( midnight / 86400 )).0;/" \
      -e "s/const float SKY_CLOCK = 0.0;/const float SKY_CLOCK = $(( SHADERBG_EPOCH - midnight )).0;/" \
      ${spaceShader} > "$base"

    # Event ids, odds and names (see eventTable).
    table=$(${pkgs.coreutils}/bin/cat ${eventTable})
    period=$(${pkgs.gawk}/bin/awk '/^const float EVENT_PERIOD = / { v = $5; sub(/;/, "", v); print int(v) }' "$base")
    gap=$(${pkgs.gawk}/bin/awk '/^const float SWAP_GAP = / { v = $5; sub(/;/, "", v); print int(v) }' "$base")
    outHash=$(printf %s "$output" | ${pkgs.coreutils}/bin/cksum | ${pkgs.coreutils}/bin/cut -d' ' -f1)

    # Which event slot k shows: id and name, the same every time for this seed and output.
    pick() {
      printf '%s\n' "$table" | ${pkgs.gawk}/bin/awk -v s="$seed" -v k="$1" -v o="$outHash" '
        $1 == "plain" { plain = $2; next }
        { ids[++n] = $1; ws[n] = $2; nm[n] = $3; tot += $2 }
        END {
          srand((s * 7919 + k * 104729 + o) % 2147483647); r = rand()
          if (r < plain) { print 0, "plain"; exit }
          x = (r - plain) / (1 - plain) * tot
          for (i = 1; i <= n; i++) { x -= ws[i]; if (x < 0) { print ids[i], nm[i]; exit } }
          print ids[n], nm[n]
        }'
    }

    # Take the scene shaders down with this script, however it ends.
    trap 'kill $(jobs -p) 2>/dev/null' EXIT
    trap 'exit 0' TERM INT
    cur=""
    curSlot=-1
    old=""
    killAt=0
    while true; do
      t=$(( ''${EPOCHREALTIME%.*} - SHADERBG_EPOCH ))
      k=$(( t / period ))
      # Hand over to the next slot's scene a moment into this slot's plain-sky gap.
      want=$k
      if [ $t -ge $(( (k + 1) * period - gap + 2 )) ]; then
        want=$(( k + 1 ))
      fi
      if [ "$want" != "$curSlot" ]; then
        read -r id name <<< "$(pick "$want")"
        frag="$dir/$output-$want.frag"
        ${pkgs.gnused}/bin/sed -e "s/const int FORCE_EVENT = -1;/const int FORCE_EVENT = $id;/" \
          -e "s/const float SHOW_FROM = -1.0e9;/const float SHOW_FROM = $(( want * period )).0;/" \
          -e "s/const float SHOW_UNTIL = 1.0e9;/const float SHOW_UNTIL = $(( (want + 1) * period - gap )).0;/" \
          "$base" > "$frag"
        echo "slot $want: $name"
        ${shaderbg}/bin/shaderbg --fps 20 --layer background "$output" "$frag" &
        if [ -n "$cur" ]; then
          old=$cur
          oldFrag=$curFrag
          # Long enough for the new shader to compile and start drawing.
          killAt=$(( t + 20 ))
        fi
        cur=$!
        curFrag=$frag
        curSlot=$want
      fi
      if [ -n "$old" ] && [ $t -ge $killAt ]; then
        kill "$old" 2>/dev/null
        wait "$old" 2>/dev/null
        ${pkgs.coreutils}/bin/rm -f "$oldFrag"
        old=""
      fi
      # If the scene's shader died, exit so systemd restarts the wallpaper.
      if ! kill -0 "$cur" 2>/dev/null; then
        echo "shaderbg exited" >&2
        exit 1
      fi
      ${pkgs.coreutils}/bin/sleep 2
    done
  '';

  # Show one event, or one kind of background sky, on demand instead of waiting for the roll.
  preview = pkgs.writeShellScriptBin "space-wallpaper-preview" ''
    skies="nebula milkyway deepfield cirrus void"
    # Scene names in id order, from the shader's event table.
    events=$(${pkgs.gawk}/bin/awk '$1 != "plain"' ${eventTable} | ${pkgs.coreutils}/bin/sort -n | ${pkgs.gawk}/bin/awk '{ print $3 }' | ${pkgs.coreutils}/bin/tr '\n' ' ')
    if [ $# -lt 1 ]; then
      echo "usage: space-wallpaper-preview <event|sky> [output] [seconds] [seed]"
      echo "events: $events"
      echo "skies: $skies"
      exit 1
    fi
    id=0
    extra=""
    sky=-1
    for s in $skies; do
      sky=$((sky + 1))
      if [ "$s" = "$1" ]; then
        # A background sky on its own, with no event.
        name=$1
        id=0
        extra="s/const int FORCE_SKY = -1;/const int FORCE_SKY = $sky;/"
        break
      fi
    done
    if [ -z "$extra" ]; then
      name=$1
      id=$(${pkgs.gawk}/bin/awk -v n="$1" '$3 == n { print $1 }' ${eventTable})
    fi
    if [ -z "$extra" ] && [ -z "$id" ]; then
      echo "unknown event '$1'; events: $events; skies: $skies"
      exit 1
    fi
    output=''${2:-DP-2}
    seconds=''${3:-20}
    seed=''${4:-}
    ${pickSeed}
    frag=$(mktemp --suffix=.frag)
    trap 'rm -f "$frag"' EXIT
    ${pkgs.gnused}/bin/sed -e "s/const int FORCE_EVENT = -1;/const int FORCE_EVENT = $id;/" \
      -e 's/const float EVENT_FADE = 20.0;/const float EVENT_FADE = 0.001;/' \
      -e "${seedSed}" -e "s/const float SKY_DAY = 0.0;/const float SKY_DAY = $seed.0;/" \
      -e "$extra" ${spaceShader} > "$frag"
    ${pkgs.coreutils}/bin/timeout "$seconds" ${shaderbg}/bin/shaderbg --fps 20 --layer overlay "$output" "$frag"
    true
  '';

  # Freeze a monitor's shader (0 fps) while anything is open on it: a window on its active workspace,
  # or a special (scratchpad) workspace shown over it. It only animates on an empty desktop.
  pauser = pkgs.writeShellScript "space-wallpaper-pauser" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.socat
        pkgs.systemd
        config.wayland.windowManager.hyprland.package
      ]
    }:$PATH

    update() {
      workspaces=$(hyprctl -j workspaces)
      hyprctl -j monitors | jq -r '.[] | "\(.name) \(.activeWorkspace.id) \(.specialWorkspace.id // 0)"' | while read -r mon ws special; do
        busy=$(jq --argjson id "$ws" --argjson sp "$special" \
          'any(.[]; (.id == $id or ($sp != 0 and .id == $sp)) and .windows > 0)' <<<"$workspaces")
        if [ "$busy" = true ]; then
          sig=STOP
        else
          sig=CONT
        fi
        systemctl --user kill --signal="$sig" "space-wallpaper@$mon.service" 2>/dev/null || true
      done
    }

    update
    # Also recheck periodically: a wallpaper instance that restarts behind a window
    # starts unpaused, and no Hyprland event fires for that.
    (while sleep 5; do update; done) &
    socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r event; do
      case "$event" in
        fullscreen\>\>* | workspace\>\>* | focusedmon\>\>* | openwindow\>\>* | closewindow\>\>* | movewindow\>\>* | moveworkspace\>\>* | activespecial\>\>*)
          update
          ;;
      esac
    done
  '';

  toggle = pkgs.writeShellScriptBin "space-wallpaper-toggle" ''
    if systemctl --user is-active --quiet space-wallpaper.target; then
      systemctl --user stop space-wallpaper.target
    else
      systemctl --user start space-wallpaper.target
    fi
  '';

  # Keep retrying instead of hitting systemd's start limit while the compositor is down.
  resilient = {
    Restart = "always";
    RestartSec = 2;
  };
in
{
  home.packages = [
    toggle
    preview
  ];

  systemd.user.targets.space-wallpaper = {
    Unit = {
      Description = "Animated space wallpaper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Wants = map instance monitors ++ [ "space-wallpaper-pauser.service" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services."space-wallpaper@" = {
    Unit = {
      Description = "Animated space wallpaper on %i";
      PartOf = [ "space-wallpaper.target" ];
      After = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = resilient // {
      ExecStart = "${launch} %i";
    };
  };

  systemd.user.services.space-wallpaper-pauser = {
    Unit = {
      Description = "Pause the space wallpaper behind fullscreen windows";
      PartOf = [ "space-wallpaper.target" ];
      After = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = resilient // {
      ExecStart = "${pauser}";
    };
  };
}
