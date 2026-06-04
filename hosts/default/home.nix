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
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Prisma engines — NixOS can't use Prisma's downloaded binaries
  home.sessionVariables = {
    PRISMA_QUERY_ENGINE_LIBRARY = "${pkgs.prisma-engines}/lib/libquery_engine.node";
    PRISMA_QUERY_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/query-engine";
    PRISMA_SCHEMA_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/schema-engine";
    PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING = "1";
  };
    # This is likely what is triggering the error:

  # Import Program Configurations
  imports = [
    ../../config/hyprland/hyprland.nix
    ../../config/emoji.nix
#    ../../config/nvim/neovim.nix
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
    settings = {
        user = {
            name = "${gitUsername}";
            email = "${gitEmail}";
        };
        core = {
            editor = "vim";
        };
    };
 };

  # Create XDG Dirs
  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/terminal" = "kitty.desktop";
        "inode/directory" = "thunar.desktop";
        "x-scheme-handler/file" = "thunar.desktop";
      };
    };
  };

  # Thunar terminal helper (XFCE uses its own helper system)
  home.file.".config/xfce4/helpers.rc".text = ''
    TerminalEmulator=kitty
  '';

  # Steam wrapper for Flatpak (game shortcuts call "steam steam://...")
  # Blocked on weekdays 6 AM - 6 PM CT
  home.file.".local/bin/steam" = {
    executable = true;
    text = ''
      #!/bin/sh
      DAY=$(date +%u)   # 1=Mon..5=Fri, 6=Sat, 7=Sun
      HOUR=$(date +%-H)

      if [ "$DAY" -le 5 ] && [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then
        notify-send -u normal -a "Steam Block" \
          "Steam is blocked on weekdays from 6 AM to 6 PM."
        exit 1
      fi

      flatpak override --user \
        --filesystem='/mnt/game_disc' \
        --filesystem='/home/jonkoi/Documents/r2modman' \
        --share=network \
        com.valvesoftware.Steam
      exec flatpak run com.valvesoftware.Steam "$@"
    '';
  };

  # Override Zed desktop entry to use zed-open (bypasses bwrap sandbox GPU issues)
  home.file.".local/share/applications/dev.zed.Zed.desktop".text = ''
    [Desktop Entry]
    Name=Zed
    Comment=High-performance, GPU-accelerated code editor
    Exec=zed-open %U
    Icon=dev.zed.Zed
    Terminal=false
    Type=Application
    Categories=Development;Editor;TextEditor;
    MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++src;text/x-java;text/x-js;text/x-objcsrc;text/x-php;text/x-python;text/x-ruby;text/x-sh;application/x-php;application/xhtml+xml;application/xml;
  '';

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };

  gtk = {
  enable = true;
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
    (import ../../scripts/ai-usage.nix { inherit pkgs; })
    (import ../../scripts/vaultwarden-backup.nix {
      inherit pkgs;
      inherit username;
    })
    (import ../../scripts/zed-open.nix { inherit pkgs; })
    pkgs.papirus-icon-theme
    pkgs.xdg-desktop-portal-gtk
  ];

 # Configure Cursor Theme
  home.pointerCursor = {
    gtk.enable = false;
    x11.enable = false;
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
        export PATH="$HOME/.local/bin:$PATH"
        #if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
        #  exec Hyprlandx
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
