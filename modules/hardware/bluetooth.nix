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

  # Disable runtime power management on the BT adapter to prevent mid-drag disconnects
  systemd.services.bt-disable-autosuspend = {
    description = "Disable autosuspend on Bluetooth USB adapter";
    after = [ "bluetooth.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'for dev in /sys/bus/usb/devices/*/; do if [ -f \"$dev/idVendor\" ] && [ \"$(cat $dev/idVendor)\" = \"2357\" ] && [ \"$(cat $dev/idProduct)\" = \"0604\" ]; then echo on > \"$dev/power/control\"; echo -1 > \"$dev/power/autosuspend_delay_ms\"; fi; done'";
    };
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
        IdleTimeout = "0";
      };
      LE = {
        ConnectionParameters = "6,9,0,600";
      };
      Policy = {
        AutoEnable = "true";
        ReconnectUUIDs = "00001124-0000-1000-8000-00805f9b34fb,00001200-0000-1000-8000-00805f9b34fb";
      };
    };
  };

  hardware.xpadneo.enable = true;
}