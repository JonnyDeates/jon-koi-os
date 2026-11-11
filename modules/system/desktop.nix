{ pkgs, ... }:

{
  programs = {
    xfconf.enable = true;
    dconf.enable = true;
    # Application for managing encryption keys and passwords
    seahorse.enable = true;

    # File manager
    thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-archive-plugin
        thunar-volman
      ];
    };

    # Run AppImages directly (installs appimage-run and registers both AppImage types)
    appimage = {
      enable = true;
      binfmt = true;
    };

    # Hyprland
    hyprland.enable = true;
  };

  environment.systemPackages = with pkgs; [
    lxqt.lxqt-policykit # A PolicyKit authentication agent for the LXQt desktop environment. It handles authorization for various system-level tasks.
    mangohud # An overlay for Vulkan and DirectX applications that shows real‑time performance metrics (e.g., FPS, CPU/GPU usage) while gaming.
    wl-clipboard # A command‑line utility for accessing the Wayland clipboard (copying and pasting) in scripts or terminal sessions.
    vipsdisp # Tiny image viewer with libvips
    swappy # A tool for annotating screenshots, often used in Wayland environments to quickly mark up images.
    yad # “Yet Another Dialog”—a tool that creates simple graphical dialog boxes from shell scripts.
    grim # A screenshot utility for Wayland compositors—it captures the screen (or a region) and outputs an image.
    slurp # A selection tool for Wayland that lets you interactively select a region of the screen (often used in tandem with grim).
    swaynotificationcenter # A notification center tailored for the Sway window manager, helping to organize and view notifications.
    file-roller # The default graphical archive manager for GNOME (often simply called “Archive Manager”), used to view and extract archive files.
    imv # A simple image viewer that works well on both Wayland and X11.
    transmission_4-gtk # The GTK‑based graphical interface for Transmission, a BitTorrent client.
    mpv # A versatile media player capable of playing video and audio with high‑quality output and extensive format support.
    hyprpicker
    hypridle
    remmina # A remote desktop client that supports multiple protocols (such as RDP, VNC, and SSH) to access other computers.
  ];

  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
    libinput.enable = true;
    gvfs.enable = true;
    gnome.gnome-keyring.enable = true;
    tumbler.enable = true;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
    };
  };

  security.pam.services.hyprlock = { };
}
