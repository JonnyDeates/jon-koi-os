{
pkgs,
lib,
...
}: {
  environment.systemPackages = with pkgs; [
    sddm-astronaut
    kdePackages.qtmultimedia
    kdePackages.qtsvg
    kdePackages.qtvirtualkeyboard
    kdePackages.qtbase
    ];
    services = {
        xserver = {
        enable = true;
        displayManager.setupCommands = ''
            ${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --primary --auto
            ${pkgs.xorg.xrandr}/bin/xrandr --output DP-2 --off
            ${pkgs.xorg.xrandr}/bin/xrandr --output DP-3 --off
        '';
          };

        displayManager = {
            sddm = {
                enable = true; # Enable SDDM.
                wayland.enable = true;
                theme = "sddm-astronaut-theme";

                extraPackages = with pkgs; [
                    sddm-astronaut
                    # The core Qt6 libraries needed for this theme
                    kdePackages.qt6ct
                    kdePackages.qtmultimedia
                    kdePackages.qtsvg
                      kdePackages.qtvirtualkeyboard

                    # IMPORTANT: Many "Qt6" themes still use old QML effects
                    # This package provides the "Qt5Compat" module often missing
                    kdePackages.qt5compat
                    kdePackages.qtdeclarative
                    # --- NEW ADDITIONS BASED ON THE SCRIPT ---
                                  # Video backends are required for the video background to play!
                                  kdePackages.qtmultimedia.out # Sometimes the lib is split
                                  ffmpeg
                                  gst_all_1.gstreamer
                                  gst_all_1.gst-plugins-base
                                  gst_all_1.gst-plugins-good
                                  gst_all_1.gst-plugins-bad
                                  gst_all_1.gst-libav
                ];
                };
            };
        };
}
