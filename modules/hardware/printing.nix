{
pkgs,
...
}: {

  environment.systemPackages =
    with pkgs;
  [
     epson-escpr
     epson-escpr2
#     epson_201207w
#     epson-201401w
#     epson-201106w
  ];
    services = {
    # Facilitates zero-configuration networking (service discovery using mDNS/DNS‑SD).
       avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
        };
        printing = {
          listenAddresses = [ "*:631" ];
          allowFrom = [ "192.168.1.139" "192.168.1.9" ];
          browsing = true;
          defaultShared = true;
          openFirewall = true;
            enable = true;
            drivers = [
              pkgs.epson-escpr
              pkgs.epson-escpr2
            ];
        };
  };
}
