{
pkgs,
...
}: {
  environment.systemPackages =
    with pkgs;
  [
    # A command‑line utility that lets you control media players (play, pause, next, etc.) that support the MPRIS D‑Bus interface.
    playerctl
    # A volume control application (“PulseAudio Volume Control”) that provides fine‑grained control over your audio streams and devices.
    pavucontrol
    # A modern multimedia server that handles audio and video streams, increasingly used as a replacement for PulseAudio and JACK.
    pipewire
    # A session and policy manager for PipeWire that handles the configuration and routing of multimedia streams.
    wireplumber
  ];
    services = {
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;

        wireplumber.extraConfig = {
                                 "monitor.bluez.properties" = {
                                     "bluez5.enable-sbc-xq" = true;
                                     "bluez5.enable-msbc" = true;
                                     "bluez5.enable-hw-volume" = true;
                                     "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
                                 };
      };
    };
  };
}
