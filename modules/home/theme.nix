{ pkgs, ... }:

{
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

  # Configure Cursor Theme
  home.pointerCursor = {
    gtk.enable = false;
    x11.enable = false;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 64;
  };
}
