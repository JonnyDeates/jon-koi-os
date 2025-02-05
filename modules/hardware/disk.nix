{
pkgs,
username,
...
}: {
  environment.systemPackages =
    with pkgs;
    [
        # Also known as “Disks,” this graphical tool helps manage and monitor disk drives and partitions.
        gnome-disk-utility
        # A disk usage utility that provides a human‑friendly overview of disk space usage (similar to df but with a nicer interface).
        duf
    ];
    services = {
        smartd = {
          # The SMART disk monitoring daemon
          enable = false;
          autodetect = true;
        };
        # Disables the periodic trimming of SSDs (which helps maintain SSD performance over time). You might disable it if you’re handling trim in another way or if it’s not needed for your hardware.
        fstrim.enable = false;

        # Activates the udisks2 service, which provides tools for managing storage devices (such as mounting/unmounting disks).
        udisks2.enable = true;

        # The Syncthing service (for file synchronization across devices)
        syncthing = {
              enable = false;
              user = "${username}";
              dataDir = "/home/${username}";
              configDir = "/home/${username}/.config/syncthing";
        };
      };
}