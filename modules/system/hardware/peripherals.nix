{ pkgs, ... }:

{
  # Scanner
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
    disabledDefaultBackends = [ "escl" ];
  };
  services.ipp-usb.enable = true;

  # Logitech receiver (MX Vertical)
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  hardware.ledger.enable = true;

  # ZSA keyboard (Moonlander) flashing
  hardware.keyboard.zsa.enable = true;
}
