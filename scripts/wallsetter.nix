{ pkgs, username, ... }:

pkgs.writeShellScriptBin "wallsetter" ''

  DIRECTORY="/home/${username}/Pictures/Wallpapers"

  if [ -d "$DIRECTORY" ]; then

    num_files_horizontal=$(ls -1 "$DIRECTORY/Horizontal" | wc -l)

    if [ $num_files_horizontal -lt 1 ]; then
      notify-send -t 9000 "The wallpaper folder is expected to have more than 1 image. Exiting Wallsetter."
      exit
    fi
    num_files_portait=$(ls -1 "$DIRECTORY/Portrait" | wc -l)

    if [ $num_files_portait -lt 1 ]; then
      notify-send -t 9000 "The wallpaper folder is expected to have more than 1 image. Exiting Wallsetter."
      exit
    fi

    mapfile -t IMAGES < <(shuf -e "$DIRECTORY"/Horizontal/*.{jpg,jpeg,png,gif} | head -n 2)
    mapfile -t IMAGES_PORTAIT < <(shuf -e "$DIRECTORY"/Portrait/*.{jpg,jpeg,png,gif} | head -n 1)

    # Check if we got at least three images
    if [ "''${#IMAGES[@]}" -lt 2 ]; then
      notify-send -t 9000 "Not enough images found after shuffling. Exiting Wallsetter."
      exit 1
    fi
    if [ "''${#IMAGES[@]}" -lt 1 ]; then
      notify-send -t 9000 "Not enough images found after shuffling. Exiting Wallsetter."
      exit 1
    fi
    IMG1="''${IMAGES[0]}"
    IMG2="''${IMAGES[1]}"
    IMG3="''${IMAGES_PORTAIT[0]}"

    echo "Image 1: $IMG1"
    echo "Image 2: $IMG2"
    echo "Image 3: $IMG3"

    hyprctl hyprpaper preload "$IMG1"
    hyprctl hyprpaper wallpaper DP-1, "$IMG1"

    sleep 0.5

    hyprctl hyprpaper preload "$IMG2"
    hyprctl hyprpaper wallpaper DP-2, "$IMG2"

    sleep 0.5

    hyprctl hyprpaper preload "$IMG3"
    hyprctl hyprpaper wallpaper DP-3, "$IMG3"

    hyprctl hyprpaper unload all
  else
    notify-send -t 9000 "Directory $DIRECTORY does not exist. Exiting Wallsetter."
    exit 1
  fi
''
