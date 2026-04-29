{ config, pkgs, lib, username, ... }:

let
  deskthingTriggerScript = pkgs.writeShellScript "deskthing-udev-trigger" ''
    # Wait for USB device to fully settle after plug event
    sleep 3

    # Check if the user's graphical session is running
    if [ ! -S /run/user/1000/wayland-1 ] && [ ! -S /run/user/1000/wayland-0 ]; then
      echo "deskthing-udev-trigger: graphical session not ready, skipping restart"
      exit 0
    fi

    # Restart the user-level DeskThing service
    ${pkgs.util-linux}/bin/runuser -l ${username} -- \
      env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
      ${pkgs.systemd}/bin/systemctl --user restart deskThingService

    echo "deskthing-udev-trigger: deskThingService restart requested"
  '';
in
{
  config = {
    # udev rules for Spotify Car Thing (Superbird)
    services.udev.extraRules = ''
      # Grant plugdev group access to Car Thing
      SUBSYSTEM=="usb", ATTR{idVendor}=="1d6b", ATTR{idProduct}=="1014", MODE="0666", GROUP="plugdev"
      # Trigger DeskThing service restart on hotplug
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1d6b", ATTR{idProduct}=="1014", TAG+="systemd", ENV{SYSTEMD_WANTS}+="deskthing-udev-trigger.service"
    '';

    # System-level oneshot service triggered by udev
    systemd.services.deskthing-udev-trigger = {
      description = "Trigger DeskThing user service on USB hotplug";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStart = "${deskthingTriggerScript}";
      };
    };
  };
}
