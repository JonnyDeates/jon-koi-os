{
pkgs,
...
}:
{
environment.systemPackages = with pkgs; [
blueman
];

boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=1
    options xpadneo disable_ff=1
    options xpadneo trigger_rumble_mode=2
'';

# xpad no longer blacklisted - allows wired USB connections to work
# boot.blacklistedKernelModules = [ "xpad" ];

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
        Experimental = "true";
        ReconnectAttempts = "7";
        ReconnectIntervals = "1,2,4,8,16,32,64";
      };
      LE = {
        ConnectionParameters = "11,15,0,600";
      };
      Policy = {
        AutoEnable = "true";
        ReconnectUUIDs = "00001124-0000-1000-8000-00805f9b34fb,00001200-0000-1000-8000-00805f9b34fb";
      };
    };
  };

  hardware.xpadneo.enable = true;
}