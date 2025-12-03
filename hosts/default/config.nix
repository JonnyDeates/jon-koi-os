{
  config,
  pkgs,
  host,
  inputs,
  username,
  options,
  lib,

  ...
}:

{
  imports = [
    ./hardware.nix
    ./users.nix
    # Drivers
    ../../modules/drivers/amd-drivers.nix
    ../../modules/drivers/nvidia-drivers.nix
    ../../modules/drivers/nvidia-prime-drivers.nix
    ../../modules/drivers/intel-drivers.nix

    # Virtualization
    ../../modules/virtualization/docker.nix
    ../../modules/virtualization/kubernetes.nix
    ../../modules/virtualization/vm-guest-services.nix

    # Hardware
    ../../modules/hardware/audio.nix
    ../../modules/hardware/bluetooth.nix
    ../../modules/hardware/disk.nix
    ../../modules/hardware/local-hardware-clock.nix
    ../../modules/hardware/networking.nix
    ../../modules/hardware/printing.nix

    # Gaming
    ../../modules/gaming/flatpak.nix

    # OS Styling
    ../../modules/os-styling/fonts.nix
    ../../modules/os-styling/login-screen.nix
    ../../modules/os-styling/starship.nix

    # General Apps
    ../../modules/apps.nix

    # System Commands
    ../../aliases/system-bash-aliases.nix
    ../../aliases/git-aliases.nix
    ../../aliases/quit-aliases.nix
    ../../aliases/gaming-aliases.nix
    ../../aliases/virtualization.nix
];

hardware.enableAllFirmware = true;
 boot = {
    # Kernel
    kernelPackages = pkgs.linuxPackages_latest;
    # This is for OBS Virtual Cam Support
    kernelModules = [ "v4l2loopback" ];
    extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    # Needed For Some Steam Games
    kernel.sysctl = {
      "vm.max_map_count" = 2147483642;
    };
    # Bootloader.
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # Make /tmp a tmpfs
    tmp = {
      useTmpfs = false;
      tmpfsSize = "30%";
    };
    # Appimage Support
    binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
      magicOrExtension = ''\x7fELF....AI\x02'';
    };
    plymouth.enable = true;
  };

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  programs = {
    adb.enable = true;
    xfconf.enable = true;
    dconf.enable = true;
    # Application for managing encryption keys and passwords
    seahorse.enable = true;

    # Allows file systems in userspace
    fuse.userAllowOther = true;

    # Modern release of the GNU Privacy Guard, a GPL OpenPGP implementation
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    # File manager
    thunar = {
      enable = true;
      plugins = with pkgs.xfce; [ thunar-archive-plugin thunar-volman ];
    };

    # Allows for app images to be installed
    appimage.binfmt = true;

    # Hyprland
    hyprland.enable = true;

  };

  users = {
    mutableUsers = true;
  };

  environment.variables = {
       HSA_OVERRIDE_GFX_VERSION = "11.0.0";
       AMD_VULKAN_ICD = "RADV";
       VK_ICD_FILENAMES="/run/host/usr/share/vulkan/icd.d/radeon_icd.x86_64.json";
  };

  environment.systemPackages =
    with pkgs;
    [
      vim
      wget
      killall
      eza # basically just ls
      git
      fastfetch
      htop
      lxqt.lxqt-policykit # A PolicyKit authentication agent for the LXQt desktop environment. It handles authorization for various system-level tasks.
      mangohud # An overlay for Vulkan and DirectX applications that shows real‑time performance metrics (e.g., FPS, CPU/GPU usage) while gaming.
      lm_sensors # A utility to monitor hardware sensors
      unzip # A tool for extracting files from ZIP archives.
      unrar # A utility to extract files from RAR archives.
      libnotify # A library that enables desktop applications to send user notifications.
      v4l-utils # A collection of command‑line utilities for controlling and testing Video4Linux devices
      # ydotool # A tool to simulate keyboard and mouse input on Wayland systems
      wl-clipboard # A command‑line utility for accessing the Wayland clipboard (copying and pasting) in scripts or terminal sessions.
      pciutils # A set of utilities (like lspci) that provide information about PCI buses and devices on your system.
      espeak-ng
      # ripgrep
      # lsd another ls replacement
      lshw # A tool that displays detailed information about your hardware configuration.
      pkg-config # A helper tool used when compiling applications; it retrieves metadata about installed libraries (such as compiler and linker flags).
      # meson # A build system designed for speed and ease of use, commonly used in modern software development.
      # gnumake # The GNU implementation of the make build automation tool, which reads makefiles to compile and build programs.
      # libgccjit
      # ninja # A small, fast build system that is designed to have its input files generated by higher‑level build systems (like Meson).
      # brightnessctl # A command‑line utility for adjusting the screen brightness.
      vipsdisp # Tiny image viewer with libvips
      swappy # A tool for annotating screenshots, often used in Wayland environments to quickly mark up images.
      appimage-run # A helper utility to run AppImage packages (self‑contained Linux applications) seamlessly.
      yad # “Yet Another Dialog”—a tool that creates simple graphical dialog boxes from shell scripts.
      nh # Nixos helper
      nixfmt-rfc-style # A formatter for Nix expressions that reformats code according to RFC style guidelines.

      grim # A screenshot utility for Wayland compositors—it captures the screen (or a region) and outputs an image.

      slurp # A selection tool for Wayland that lets you interactively select a region of the screen (often used in tandem with grim).
      swaynotificationcenter # A notification center tailored for the Sway window manager, helping to organize and view notifications.

      file-roller # The default graphical archive manager for GNOME (often simply called “Archive Manager”), used to view and extract archive files.
      imv # A simple image viewer that works well on both Wayland and X11.
      transmission_4-gtk # The GTK‑based graphical interface for Transmission, a BitTorrent client.

      mpv # A versatile media player capable of playing video and audio with high‑quality output and extensive format support.
      # rustup # The official installer and version manager for the Rust programming language toolchain.

     # tree # A command‑line program that displays directory structures in a tree‑like format.

      neovide # A graphical (GUI) client for Neovim that offers additional interface enhancements compared to the terminal version.
      hyprpicker
      hyprpaper
      hypridle
      swww # A wallpaper setter for Wayland compositors (often used with Sway or Hyprland) that makes changing backgrounds easier.
      ffmpeg # A comprehensive multimedia framework for recording, converting, and streaming audio and video.

      gammastep

      nodejs_22
      nodePackages.pnpm

      remmina # A remote desktop client that supports multiple protocols (such as RDP, VNC, and SSH) to access other computers.
      # bat basically cat
      inxi # A command‑line tool that displays detailed system information about your hardware and software configuration.
      starship # A minimal, customizable, and fast shell prompt that works with many different shells.
      usbutils # A set of utilities (like lsusb) for listing and interacting with USB devices connected to your computer.
    ];

  # Services to start
  services = {
    speechd.enable = true;
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
    libinput.enable = true;
    gvfs.enable = true;
    openssh.enable = true;
    gnome.gnome-keyring.enable = true;
   # power-profiles-daemon.enable = true;

   tumbler.enable = true;
   ipp-usb.enable = true;
    rpcbind.enable = false;
    nfs.server.enable = false;
  };

  xdg.portal = {
   enable = true;
    wlr.enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal
    ];
   configPackages = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal
    ];
  };

  

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
    disabledDefaultBackends = [ "escl" ];
  };
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;


  hardware.ledger.enable = true;
  hardware.keyboard.zsa.enable = true;

  # Security / Polkit
  security.rtkit.enable = true;
  security.polkit.enable = true;
  security.pam.services.hyprlock = {};
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.isInGroup("users")
          && (
            action.id == "org.freedesktop.login1.reboot" ||
            action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
            action.id == "org.freedesktop.login1.power-off" ||
            action.id == "org.freedesktop.login1.power-off-multiple-sessions"
          )
        )
      {
        return polkit.Result.YES;
      }
    })
  '';
  security.sudo.extraRules = [
  {
    users = ["jonkoi"]; groups = [1006];
    commands = [ {command = "/run/current-system/sw/bin/adb"; options = ["SETENV" "NOPASSWD"]; }];
  }
  ];
  # Optimization settings and garbage collection automation
  nix = {
    settings = {
      auto-optimise-store = true;
      download-buffer-size = 52428800;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [ "https://hyprland.cachix.org" ];
      trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # Extra Module Options
  drivers.amdgpu.enable = true;
  drivers.nvidia.enable = false;
  drivers.nvidia-prime = {
    enable = false;
    intelBusID = "";
    nvidiaBusID = "";
  };
  drivers.intel.enable = false;
  vm.guest-services.enable = false;
  local.hardware-clock.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
