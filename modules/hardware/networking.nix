{
pkgs,
options,
host,
...
}: {

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  networking.hostName = "${host}";
  networking.timeServers = options.networking.timeServers.default ++ [ "pool.ntp.org" ];

  environment.systemPackages =
    with pkgs;
    [
      # A system tray applet that provides a graphical interface for managing network connections via NetworkManager.
      networkmanagerapplet
      # A versatile utility that establishes two bidirectional byte streams and transfers data between them (useful for networking and debugging).
      #socat
    ];
    programs = {
        # Network diagnostics tool
        mtr.enable = true;
    };
    # Open ports in the firewall.
    # networking.firewall.allowedTCPPorts = [ ... ];
    # networking.firewall.allowedUDPPorts = [ ... ];
    # Or disable the firewall altogether.
    networking.firewall = {
      enable = true;
      interfaces."enp15s0u2".allowedTCPPortRanges = [ {from = 0; to = 65534;} ];
   };
}