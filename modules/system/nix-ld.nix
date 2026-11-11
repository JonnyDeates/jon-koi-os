{ pkgs, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      glib
      dbus
      expat
      fontconfig
      freetype
      libxkbcommon

      libGL
      libglvnd

      xorg.libX11
      xorg.libXcursor
      xorg.libXext
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXtst
      xorg.libXxf86vm
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXfixes
      xorg.libxcb
      xorg.libxkbfile

      alsa-lib
      libpulseaudio

      gtk3
      cairo
      pango
      gdk-pixbuf
      atk
      nspr
      nss
      cups

      curl
      openssl
      icu
    ];
  };
}
