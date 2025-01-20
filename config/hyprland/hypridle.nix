{
  pkgs,
  ...
}:
{
  services.hypridle = {
      settings = {
        general = {
        enable = true;
        before_sleep_cmd = "hyprctl dispatch dpms off";
          after_sleep_cmd = "hyprctl dispatch dpms on && systemctl --user restart waybar";
          ignore_dbus_inhibit = false;
          lock_cmd = "hyprlock";
          starship = {
            enable = true;
            package = pkgs.starship;
          };
        };
        listener = [
          {
            timeout = 900;
            on-timeout = "hyprlock";
          }
          {
            timeout = 1200;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on && systemctl --user restart waybar";
          }
          {
             timeout = 1800;  # 30 minutes
             on-timeout = "systemctl suspend";  # Add explicit suspend command
             on-resume = "hyprctl dispatch dpms on && systemctl --user restart waybar";  # Ensure display is on after resume
          }
        ];
      };
  };
}
