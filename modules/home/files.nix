{ username, ... }:

# Files placed in the home directory, default apps and desktop entries.
{
  home.file."Pictures/Wallpapers" = {
    source = ./wallpapers;
    recursive = true;
  };
  home.file.".config/fastfetch" = {
    source = ./fastfetch;
    recursive = true;
  };
  home.file.".config/wlogout/icons" = {
    source = ./wlogout;
    recursive = true;
  };
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

  # Create XDG Dirs
  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/deskthing" = "deskthing.desktop";
        "x-scheme-handler/terminal" = "kitty.desktop";
        "inode/directory" = "thunar.desktop";
        "x-scheme-handler/file" = "thunar.desktop";
        "image/png" = "imv-dir.desktop";
        "image/jpeg" = "imv-dir.desktop";
        "image/gif" = "imv-dir.desktop";
        "image/webp" = "imv-dir.desktop";
        "image/bmp" = "imv-dir.desktop";
        "image/tiff" = "imv-dir.desktop";
        "image/svg+xml" = "imv-dir.desktop";
        "image/avif" = "imv-dir.desktop";
      };
    };
  };

  # Thunar terminal helper (XFCE uses its own helper system)
  home.file.".config/xfce4/helpers.rc".text = ''
    TerminalEmulator=kitty
  '';

  # Steam wrapper for Flatpak (game shortcuts call "steam steam://...")
  # Time block DISABLED — kept for easy re-enable
  home.file.".local/bin/steam" = {
    executable = true;
    text = ''
      #!/bin/sh
      flatpak override --user \
        --filesystem='/mnt/game_disc' \
        --filesystem='/home/${username}/Documents/r2modman' \
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
}
