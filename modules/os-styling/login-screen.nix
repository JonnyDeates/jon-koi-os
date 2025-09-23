{
pkgs,
lib,
...
}: {
  environment.systemPackages = with pkgs; [
     kdePackages.sddm
     kdePackages.sddm-kcm
    ];
    services = {
        xserver.displayManager.setupCommands =  ''
                                                  xrandr --output DP-1 --primary \n
                                                  xrandr --output DP-2 --noprimary \n
                                                  xrandr --output DP-3 --noprimary
                                                '';
        displayManager = {
            sddm = {
                enable = true; # Enable SDDM.
                sugarCandyNix = {
                    enable = true; # This set SDDM's theme to "sddm-sugar-candy-nix".
                    settings = {
                        # Set your configuration options here.
                        # Here is a simple example:
                        Background = lib.cleanSource ../../config/wallpapers/jonkoios.png;
                        ScreenWidth = 2560;
                        ScreenHeight = 1440;
                        FormPosition = "center";
                        HaveFormBackground = true;
                        PartialBlur = true;
                        RoundCorners = 16;
                    };
                  };
                };
            };
        };
}
