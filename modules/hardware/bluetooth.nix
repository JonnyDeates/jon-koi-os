{
pkgs,
...
}:
{
environment.systemPackages = with pkgs; [
blueman
linuxKernel.packages.linux_zen.xpadneo
];
boot.extraModprobConfig = ''
    options bluetooth disable_ertm=1
'';

boot.blacklistedKernelModules = [ "xpad" ];
  services = {
    blueman.enable = true;
  };
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Privacy = "device";
        ControllerMode = "dual";
        JustWorksRepairing = "always";
        Class = "0x000100";
        FastConnectable = "true";
      };
#      Policy = {
#        AutoEnable = true;
#      };
    };
  };
  hardware.xpadneo.enable = true;
}