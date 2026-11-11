{ config, pkgs, ... }:

# Host-specific settings for this machine. Shared configuration lives in modules/system.
{
  imports = [
    ./hardware.nix
    ./users.nix
    ../../modules/system
  ];

  hardware.enableAllFirmware = true;
  boot = {
    # Kernel
    kernelPackages = pkgs.linuxPackages_latest; # Newest amdgpu fixes; 6.12 hit RDNA3 MES hangs. Fallback: pkgs.linuxPackages_6_18 (LTS)
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
    # /tmp stays on disk and is wiped at boot
    tmp = {
      useTmpfs = false;
      cleanOnBoot = true;
    };
    plymouth.enable = true;
  };

  environment.variables = {
    HSA_OVERRIDE_GFX_VERSION = "11.0.0";
    AMD_VULKAN_ICD = "RADV";
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
