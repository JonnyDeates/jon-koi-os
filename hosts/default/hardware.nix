# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [
  "nvme"
  "xhci_pci"
  "ahci"
  "usbhid"
  "usb_storage"
  "sd_mod"
  "amdgpu"
  "btusb"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.kernelParams = [
 "mem_sleep_default=deep"     # Explicitly use deep sleep
  "resume=UUID=a56d2645-af86-4b76-9a7e-1d6b45464c3e"  # The UUID of the filesystem containing the swapfile
  "resume_offset=81305600"  # The offset from filefrag (first physical_offset)
  ];
  boot.extraModulePackages = [];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/a56d2645-af86-4b76-9a7e-1d6b45464c3e";
      fsType = "ext4";
    };
  fileSystems."/mnt/game_disc" =
    { device = "/dev/disk/by-uuid/cec6e902-c1ee-4f40-9398-51e259c6546e";
      fsType = "ext4";
      options = ["nofail" "x-systemd.automount" "x-systemd.after=local-fs.target" "x-systemd.device-timeout=10"];
    };
#    fileSystems."/run/media/Locked Storage" = {
#      device= "/dev/disk/by-uuid/26ECC06DECC03937";
#      fsType = "ext4";
#    };
  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/EBB3-0EDE";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [{
   device = "/swap/swapfile";
   size = 96 * 1024;
  } ];

  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp13s0.useDHCP = lib.mkDefault true;
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance";
    # Added: Power saving tweaks
    powertop.enable = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
