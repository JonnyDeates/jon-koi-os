{ pkgs, username, ... }:

{
  nixpkgs.config.allowUnfree = true;

  # Weekly /tmp cleanup — systemd-tmpfiles-clean.timer runs daily and removes
  # files older than 7d (safer than a hard wipe; leaves active sockets/locks alone).
  systemd.tmpfiles.rules = [
    "d /tmp 1777 root root 7d"
  ];

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

    # Allows file systems in userspace
    fuse.userAllowOther = true;

    # Modern release of the GNU Privacy Guard, a GPL OpenPGP implementation
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  users = {
    mutableUsers = true;
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    killall
    eza # basically just ls
    git
    fastfetch
    htop
    lm_sensors # A utility to monitor hardware sensors
    unzip # A tool for extracting files from ZIP archives.
    unrar # A utility to extract files from RAR archives.
    libnotify # A library that enables desktop applications to send user notifications.
    v4l-utils # A collection of command‑line utilities for controlling and testing Video4Linux devices
    pciutils # A set of utilities (like lspci) that provide information about PCI buses and devices on your system.
    lshw # A tool that displays detailed information about your hardware configuration.
    pkg-config # A helper tool used when compiling applications; it retrieves metadata about installed libraries (such as compiler and linker flags).
    nh # Nixos helper
    nixfmt-rfc-style # A formatter for Nix expressions that reformats code according to RFC style guidelines.
    nixd # Nix language server (used by Zed/VSCode Nix extensions for completion, diagnostics, go-to-def).
    ffmpeg # A comprehensive multimedia framework for recording, converting, and streaming audio and video.
    inxi # A command‑line tool that displays detailed system information about your hardware and software configuration.
    usbutils # A set of utilities (like lsusb) for listing and interacting with USB devices connected to your computer.
    bitwarden-cli # CLI for Bitwarden/Vaultwarden password manager
    jq # Command-line JSON processor
    libsecret
    steamcmd # CLI for downloading Steam content (dedicated servers, workshop mods)
  ];

  services = {
    speechd.enable = true;
    openssh.enable = true;
    rpcbind.enable = false;
    nfs.server.enable = false;
  };

  # Security / Polkit
  security.rtkit.enable = true;
  security.polkit.enable = true;
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
      users = [ username ];
      groups = [ 1006 ];
      commands = [
        {
          command = "/run/current-system/sw/bin/adb";
          options = [
            "SETENV"
            "NOPASSWD"
          ];
        }
      ];
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
}
