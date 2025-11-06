{
  lib,
  pkgs,
  config,
  environment,
  ...
}:
with lib;
let
  cfg = config.drivers.amdgpu;
in
{
  options.drivers.amdgpu = {
    enable = mkEnableOption "Enable AMD Drivers";
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}" ];
    services.xserver.enable = true;
    services.xserver.videoDrivers = [ "amdgpu" ];
    # OpenGL
    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      ## amdvlk: an open-source Vulkan driver from AMD
      extraPackages = with pkgs; [
           mesa
           libva
           libvdpau-va-gl
           vulkan-loader
           vulkan-validation-layers
           amdvlk
           mesa.opencl
       ];
      extraPackages32 = [ pkgs.driversi686Linux.amdvlk ];
    };
  };
};
}
