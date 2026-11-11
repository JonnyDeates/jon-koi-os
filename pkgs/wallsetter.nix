{ pkgs, username, ... }:

pkgs.writeShellScriptBin "wallsetter" ''

  DIRECTORY="/home/${username}/Pictures/Wallpapers"

  if [ -d "$DIRECTORY" ]; then
        readarray -t hlist < <(find "$DIRECTORY/Horizontal" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \))

        readarray -t plist < <(find "$DIRECTORY/Portrait" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \))

        if [ "''${#hlist[@]}" -lt 2 ]; then
            notify-send -t 9000 "Need at least 2 horizontal images. Exiting Wallsetter."
            exit 1
        fi
        if [ "''${#plist[@]}" -lt 1 ]; then
          notify-send -t 9000 "Need at least 1 portrait image. Exiting Wallsetter."
          exit 1
        fi

        mapfile -t IMAGES < <(printf '%s\n' "''${hlist[@]}" | shuf | head -n 2)
        mapfile -t IMAGES_PORTRAIT < <(printf '%s\n' "''${plist[@]}" | shuf | head -n 1)

        IMG1="''${IMAGES[0]}"
        IMG2="''${IMAGES[1]}"
        IMG3="''${IMAGES_PORTRAIT[0]}"

    echo "Image 1: $IMG1"
    echo "Image 2: $IMG2"
    echo "Image 3: $IMG3"

    sleep 2

    hyprctl hyprpaper preload "$IMG1"

    sleep 1

    hyprctl hyprpaper wallpaper DP-1, "$IMG1"

    sleep 0.5

    hyprctl hyprpaper preload "$IMG2"
    
    sleep 1

    hyprctl hyprpaper wallpaper DP-2, "$IMG2"

    sleep 0.5

    hyprctl hyprpaper preload "$IMG3"
    
    sleep 1
    
    hyprctl hyprpaper wallpaper DP-3, "$IMG3"

    sleep 1

    hyprctl hyprpaper unload all
  else
    notify-send -t 9000 "Directory $DIRECTORY does not exist. Exiting Wallsetter."
    exit 1
  fi
''
