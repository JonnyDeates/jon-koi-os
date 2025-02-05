{
  lib,
  pkgs,
  config,
  ...
}:
{


  environment.systemPackages = with pkgs; [
    # Steam
    steam-run
    mangohud
    gamemode
    # WINE
    wine
    winetricks
    protonup-qt
    protontricks
    vulkan-tools
    vulkan-loader
    # Extra dependencies
    # https://github.com/lutris/docs/
    gnutls
    openldap
    libgpg-error
    freetype
    sqlite
    libxml2
    xml2
    SDL2
    # driversi686Linux.amdvlk
    vipsdisp
    gperftools
    vulkan-tools
    libdrm
  ];
    programs = {
    gamemode = {
          enable = true;
          settings.general.inhibit_screensaver = 0;
    };

    steam = {
       enable = true;
       gamescopeSession.enable = true;
       remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
       dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
       localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local NetgamescopeSession.enable = true;work Game Transfers
       # package = pkgs.steam.override { withJava = true; };
     };
   };

nixpkgs.config = {
  allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
       "steam"
        "steam-original"
        "steam-unwrapped"
        "steam-run"
  ];

    packageOverrides = pkgs: {
    steam = pkgs.steam.override {
      extraLibraries = { pkgs, ... }: with pkgs; [
        pipewire
        xorg.libXcursor
        xorg.libXinerama
        xorg.libXext
        xorg.libXrandr
        xorg.libXrender
        xorg.libX11
        xorg.libXi
        libGL

        zlib
        dbus
        freetype
        glib
        atk
        cairo
        pango
        fontconfig
        xorg.libxcb
        harfbuzz
        gtk4
        gtk3
        gtk2
        libvdpau
      ];
      extraPkgs = pkgs: with pkgs;
        [
          zlib
          dbus
          freetype
          glib
          atk
          cairo
          pango
          fontconfig
          harfbuzz
          xorg.libxcb
        ];
    };
    };
  };
}