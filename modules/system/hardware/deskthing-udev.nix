{
  config,
  pkgs,
  lib,
  username,
  ...
}:

let
  # The Car Thing (Superbird firmware) does not enumerate on cold boot on this
  # machine — kernel sees nothing until the cable is physically replugged. The
  # usb_dev `authorized` flag is a trust bit, not a port power cycle, so it
  # can't rescue a device that never attached. The real equivalent of a physical
  # replug is unbinding and rebinding the xHCI PCI driver for the controller
  # the device lives on — that drops VBUS on every port of that controller and
  # re-initialises them, which the Car Thing responds to.
  #
  # The script locates the controller by walking from `/sys/bus/usb/devices/usb5`
  # back to its PCI parent, so you only need to update `deskthingUsbBus` if you
  # move the cable to a different port. The current controller also backs USB
  # bus 6, which is empty on this system — if you plug anything into bus 6, it
  # will also be reset on each cycle.
  deskthingUsbBus = "usb5";

  deskthingUsbResetScript = pkgs.writeShellScript "deskthing-usb-reset" ''
    # Give the kernel a moment to enumerate on its own.
    for i in $(seq 1 5); do
      if ${pkgs.usbutils}/bin/lsusb -d 1d6b:1014 > /dev/null 2>&1; then
        echo "deskthing-usb-reset: device already present, no cycle needed"
        exit 0
      fi
      sleep 2
    done

    USB_PATH=$(${pkgs.coreutils}/bin/readlink -f /sys/bus/usb/devices/${deskthingUsbBus} 2>/dev/null)
    if [ -z "$USB_PATH" ]; then
      echo "deskthing-usb-reset: /sys/bus/usb/devices/${deskthingUsbBus} not found"
      exit 0
    fi

    # Parent of usbN is the xHCI PCI device, e.g. /sys/devices/.../0000:13:00.3/usb5
    XHCI_PCI=$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/dirname "$USB_PATH")")
    DRIVER_LINK=/sys/bus/pci/drivers/xhci_hcd/$XHCI_PCI

    if [ ! -e "$DRIVER_LINK" ]; then
      echo "deskthing-usb-reset: xhci driver not bound to $XHCI_PCI"
      exit 0
    fi

    echo "deskthing-usb-reset: unbinding xhci_hcd from $XHCI_PCI"
    echo "$XHCI_PCI" > /sys/bus/pci/drivers/xhci_hcd/unbind
    sleep 3
    echo "deskthing-usb-reset: rebinding xhci_hcd to $XHCI_PCI"
    echo "$XHCI_PCI" > /sys/bus/pci/drivers/xhci_hcd/bind

    for i in $(seq 1 20); do
      if ${pkgs.usbutils}/bin/lsusb -d 1d6b:1014 > /dev/null 2>&1; then
        echo "deskthing-usb-reset: device enumerated after xhci rebind"
        exit 0
      fi
      sleep 2
    done

    echo "deskthing-usb-reset: device still missing after xhci rebind (cable issue?)"
    exit 0
  '';

  deskthingTriggerScript = pkgs.writeShellScript "deskthing-udev-trigger" ''
    # Wait for USB device to fully settle after plug event
    sleep 3

    # Check if the user's graphical session is running
    if [ ! -S /run/user/1000/wayland-1 ] && [ ! -S /run/user/1000/wayland-0 ]; then
      echo "deskthing-udev-trigger: graphical session not ready, skipping restart"
      exit 0
    fi

    # Clear any prior rate-limit / failed state, then restart.
    # `runuser -u` (not `-l`) avoids the login-shell that treats `env` as a script path.
    ${pkgs.util-linux}/bin/runuser -u ${username} -- \
      ${pkgs.coreutils}/bin/env \
        XDG_RUNTIME_DIR=/run/user/1000 \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
      ${pkgs.systemd}/bin/systemctl --user reset-failed deskThingService || true

    ${pkgs.util-linux}/bin/runuser -u ${username} -- \
      ${pkgs.coreutils}/bin/env \
        XDG_RUNTIME_DIR=/run/user/1000 \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
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

    # Boot-time software "replug" so the Car Thing enumerates without manual
    # intervention. Runs before any graphical session so the user-level
    # deskThingService sees the device when it starts.
    systemd.services.deskthing-usb-reset = {
      description = "Software-replug the Spotify Car Thing on boot";
      wantedBy = [ "multi-user.target" ];
      before = [ "graphical.target" ];
      after = [ "systemd-udev-settle.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        TimeoutStartSec = "90s";
        ExecStart = "${deskthingUsbResetScript}";
      };
    };
  };
}
