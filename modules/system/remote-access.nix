{ pkgs, ... }:

# Remote access through the OpenVPN server on pfSense. VPN clients (iPad,
# laptop) get an address in `vpnSubnet`, and pfSense routes them onto the LAN
# without NAT, so traffic arrives on eno1 from that subnet. On top of that:
#   - SSH (port 22, already enabled in core.nix)
#   - wayvnc remote desktop of the Hyprland session (port 5900), allowed ONLY
#     from the VPN subnet. wayvnc has no auth of its own here; the OpenVPN
#     cert + login is the gate, so never open 5900 more widely.
#
# vpnSubnet must match "IPv4 Tunnel Network" in pfSense's OpenVPN server.
let
  vpnSubnet = "10.0.8.0/24";
in
{
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp -s ${vpnSubnet} --dport 5900 -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -p tcp -s ${vpnSubnet} --dport 5900 -j nixos-fw-accept 2>/dev/null || true
  '';

  environment.systemPackages = [ pkgs.wayvnc ];
}
