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
    ../../modules/drivers/amd-drivers.nix
    ../../modules/drivers/nvidia-drivers.nix
    ../../modules/drivers/nvidia-prime-drivers.nix
    ../../modules/drivers/intel-drivers.nix
    ../../modules/vm-guest-services.nix
    ../../modules/local-hardware-clock.nix
    ../../modules/stylix.nix
    ../../modules/fonts.nix
    ../../aliases/system-bash-aliases.nix
    ../../aliases/git-aliases.nix
    ../../aliases/quit-aliases.nix
    ../../aliases/gaming-aliases.nix
];


 boot = {
    # Kernel
    kernelPackages = pkgs.linuxPackages_zen;
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
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  networking.hostName = "${host}";
  networking.timeServers = options.networking.timeServers.default ++ [ "pool.ntp.org" ];

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
    firefox.enable = true;
    adb.enable = true;
    starship = {
          enable = true;
          settings = {
            add_newline = false;
            buf = {
              symbol = " ";
            };
            c = {
              symbol = " ";
            };
            directory = {
              read_only = " 󰌾";
            };
            docker_context = {
              symbol = " ";
            };
            fossil_branch = {
              symbol = " ";
            };
            git_branch = {
              symbol = " ";
            };
            golang = {
              symbol = " ";
            };
            hg_branch = {
              symbol = " ";
            };
            hostname = {
              ssh_symbol = " ";
            };
            lua = {
              symbol = " ";
            };
            memory_usage = {
              symbol = "󰍛 ";
            };
            meson = {
              symbol = "󰔷 ";
            };
            nim = {
              symbol = "󰆥 ";
            };
            nix_shell = {
              symbol = " ";
            };
            nodejs = {
              symbol = " ";
            };
            ocaml = {
              symbol = " ";
            };
            package = {
              symbol = "󰏗 ";
            };
            python = {
              symbol = " ";
            };
            rust = {
              symbol = " ";
            };
            swift = {
              symbol = " ";
            };
            zig = {
              symbol = " ";
            };
          };
        };

    dconf.enable = true;
    seahorse.enable = true;
    fuse.userAllowOther = true;
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    virt-manager.enable = true;
    gamemode = {
      enable = true;
      settings.general.inhibit_screensaver = 0;
    };
#     steam = {
#      enable = true;
#        gamescopeSession.enable = true;
#       remotePlay.openFirewall = true;
#      dedicatedServer.openFirewall = true;
#    };
    thunar = {
      enable = true;
      plugins = with pkgs.xfce; [ thunar-archive-plugin thunar-volman ];
    };

    appimage.binfmt = true;
  };

  nixpkgs.config = {
  allowUnfree = true;
#  allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
#       "steam"
#      "steam-original"
#    "steam-run"
#  ];
};

  users = {
    mutableUsers = true;
  };

environment.variables = {
                HSA_OVERRIDE_GFX_VERSION = "11.0.0";
                 AMD_VULKAN_ICD = "RADV";
};

  environment.systemPackages =
    with pkgs;
    [
      vim
      wget
      killall
      eza
      git
      cmatrix
      fastfetch
      htop
      libvirt
      lxqt.lxqt-policykit
      mangohud
      lm_sensors
      unzip
      unrar
      libnotify
      v4l-utils
      ydotool
      wl-clipboard
      lm_sensors
      pciutils
      socat
      ripgrep
      lsd
      lshw
      pkg-config
      meson
      gnumake
      ninja
      brightnessctl
      virt-viewer
      swappy
      appimage-run
      networkmanagerapplet
      yad
      playerctl
      nh
      nixfmt-rfc-style
      discord
      hyprpaper
      grim
      slurp
      keepassxc
      pkgs.file-roller
      swaynotificationcenter
      imv
      transmission_4-gtk
      distrobox
      mpv
      obs-studio
      rustup
      audacity
      pavucontrol
      tree
      protonup-qt
      spotify
      neovide
      hyprpicker
      swww
      ffmpeg
      greetd.tuigreet
      r2modman
      # mesa-demos
      # libdrm
#       steam-run
      # vulkan-loader
      #vulkan-validation-layers
##      brave
       vipsdisp
      gperftools
      vulkan-tools
      keymapp

      legendary-gl
      nodejs_22
      nodePackages.pnpm
      gammastep
      libsForQt5.qt5.qtgraphicaleffects
      ledger-live-desktop
      gnome-disk-utility
      jetbrains.idea-ultimate
      remmina
      bat
      duf
      inxi
      starship
      docker-compose
    xboxdrv
    prusa-slicer
    blender
    usbutils
    antimicrox

      pipewire
      wireplumber
    ];

  # Services to start
  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
        greetd = {
          enable = true;
          vt = 3;
          settings = {
            default_session = {
              # Wayland Desktop Manager is installed only for user ryan via home-manager!
              user = username;
              # .wayland-session is a script generated by home-manager, which links to the current wayland compositor(sway/hyprland or others).
              # with such a vendor-no-locking script, we can switch to another wayland compositor without modifying greetd's config here.
              # command = "$HOME/.wayland-session"; # start a wayland session directly without a login manager
              command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland"; # start Hyprland with a TUI login manager
            };
          };
        };

    smartd = {
      enable = false;
      autodetect = true;
    };
    libinput.enable = true;
    fstrim.enable = false;
    gvfs.enable = true;
    openssh.enable = true;
    flatpak.enable = true;
    printing = {
        enable = true;
        drivers = [
          # pkgs.hplipWithPlugin
        ];
    };
    gnome.gnome-keyring.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
   tumbler.enable = true;
   udisks2.enable = true;
   ipp-usb.enable = true;
    syncthing = {
      enable = false;
      user = "${username}";
      dataDir = "/home/${username}";
      configDir = "/home/${username}/.config/syncthing";
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;

      wireplumber.extraConfig.bluetoothEnhancements = {
                               "monitor.bluez.properties" = {
                                   "bluez5.enable-sbc-xq" = true;
                                   "bluez5.enable-msbc" = true;
                                   "bluez5.enable-hw-volume" = true;
                                   "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
                               };
};

    };
    rpcbind.enable = false;
    nfs.server.enable = false;
    blueman.enable = true;
  };
  systemd.services.flatpak-repo = {
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
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

  
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        ControllerMode = "dual";
        FastConnectable = "true";
        Experimental = "true";
      };
           Policy = {
              AutoEnable = "true";
            };
    };
  };
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
    disabledDefaultBackends = [ "escl" ];
  };
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;
hardware.xpadneo.enable = true;
  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;

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

  # Virtualization / Containers
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.podman = {
    enable = true;
#    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # OpenGL

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
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  # Or disable the firewall altogether.
  networking.firewall = {
  enable = true;
  interfaces."enp15s0u2".allowedTCPPortRanges = [ {from = 0; to = 65534;} ];
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
