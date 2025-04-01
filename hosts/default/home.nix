{
  pkgs,
  username,
  host,
  ...
}:
let
  inherit (import ./variables.nix) gitUsername gitEmail;
in
{
  # Home Manager Settings
  home.username = "${username}";
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "23.11";

  # Import Program Configurations
  imports = [
    ../../config/hyprland/hyprland.nix
    ../../config/emoji.nix
    ../../config/nvim/neovim.nix
    ../../config/rofi/rofi.nix
    ../../config/rofi/config-emoji.nix
    ../../config/rofi/config-long.nix
    ../../config/swaync.nix
    ../../config/waybar.nix
    ../../config/wlogout/wlogout.nix
    ../../config/gammastep.nix
    ../../config/hyprland/hyprpaper.nix
    ../../config/hyprland/hypridle.nix
    ../../config/hyprland/hyprlock.nix
    ../../config/deskthing.nix

];

  # Place Files Inside Home Directory
  home.file."Pictures/Wallpapers" = {
    source = ../../config/wallpapers;
    recursive = true;
  };
   home.file.".config/fastfetch" = {
     source = ../../config/fastfetch;
     recursive = true;
   };
  home.file.".config/wlogout/icons" = {
    source = ../../config/wlogout;
    recursive = true;
  };
#  home.file.".face.icon".source = ../../config/face.jpg;
  home.file.".config/swappy/config".text = ''
    [Default]
    save_dir=/home/${username}/Pictures/Screenshots
    save_filename_format=swappy-%Y%m%d-%H%M%S.png
    show_panel=false
    line_size=5
    text_size=20
    text_font=Ubuntu
    paint_mode=brush
    early_exit=true
    fill_shape=false
  '';

#home.file.".local/share/flatpak/overrides/com.valvesoftware.Steam".text = ''
#  [Context]
#  filesystems=/mnt/game_disc
#'';

  # Install & Configure Git
  programs.git = {
    enable = true;
    userName = "${gitUsername}";
    userEmail = "${gitEmail}";
 };

  # Create XDG Dirs
  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };

 # home.sessionVariables = {
 #   LIBGL_DRIVERS_PATH = "${pkgs.libglvnd}/lib/libGL.so";
 # };

  # Styling Options
  stylix.targets.waybar.enable = false;
  stylix.targets.rofi.enable = false;
  stylix.targets.hyprland.enable = false;

  gtk = {
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };
  qt = {
    enable = true;
    style.name = "adwaita";
    platformTheme.name = "gtk3";
  };

  # Scripts
  home.packages = [
    (import ../../scripts/emoji-picker.nix { inherit pkgs; })
    (import ../../scripts/task-waybar.nix { inherit pkgs; })
    (import ../../scripts/nvidia-offload.nix { inherit pkgs; })
    (import ../../scripts/wallsetter.nix {
      inherit pkgs;
      inherit username;
    })
    (import ../../scripts/web-search.nix { inherit pkgs; })
    (import ../../scripts/rofi-launcher.nix { inherit pkgs; })
    (import ../../scripts/screenshootin.nix { inherit pkgs; })
    (import ../../scripts/list-hypr-bindings.nix {
      inherit pkgs;
      inherit host;
    })
    (import ../../scripts/ai-renamer.nix {inherit pkgs; })
  ];

  xresources.properties = {
    "Xcursor.size" = 64;
  };

 # Configure Cursor Theme
  home.pointerCursor = {
    gtk.enable = false;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 64;
  };

  programs = {
    gh.enable = true;
    btop = {
      enable = true;
      settings = {
        vim_keys = true;
      };
    };
    kitty = {
      enable = true;
      package = pkgs.kitty;
      settings = {
        scrollback_lines = 2000;
        wheel_scroll_min_lines = 1;
        window_padding_width = 4;
        confirm_os_window_close = 0;
      };
           extraConfig = ''
             tab_bar_style fade
             tab_fade 1
             active_tab_font_style   bold
             inactive_tab_font_style bold
           '';
    };
    starship = {
        enable = true;
        package = pkgs.starship;
    };
    bash = {
      enable = true;
      enableCompletion = true;
      profileExtra = ''
        #if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
        #  exec Hyprland
        #fi
      '';
      initExtra = ''
        fastfetch
        if [ -f $HOME/.bashrc-personal ]; then
          source $HOME/.bashrc-personal
        fi
      '';

    };
    home-manager.enable = true;
  };
}
