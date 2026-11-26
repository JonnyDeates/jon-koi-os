{
  pkgs,
  ...
}:
{
  home.file.".config/hypr/hypridle.conf".text = ''
    general {
        lock_cmd = "hyprlock"       # avoid starting multiple hyprlock instances.
        before_sleep_cmd = loginctl lock-session    # lock before suspend.
        after_sleep_cmd = hyprctl dispatch dpms on  # to avoid having to press a key twice to turn on the display.
    }
    listener {
        timeout = 1800
        on-timeout = "hyprctl dispatch dpms off"
        on-resume = "hyprctl dispatch dpms on && systemctl --user restart waybar"
    }

    listener {
        timeout = 2700
        on-timeout = "discipline-paused || systemctl suspend"  # stay awake for remote access while away
    }
  '';
}
