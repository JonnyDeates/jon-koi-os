{
  pkgs,
  username,
  lib,
  ...
}:
with lib;
{
  programs.hyprlock = {
                enable = true;
                settings = {
                  general = {
                    disable_loading_bar = false;
                    grace = 3;
                    hide_cursor = false;
                    no_fade_in = false;
                  };
                  background = [
                    {
                      path = "/home/${username}/Pictures/Wallpapers/jonkoios.png";
                      blur_passes = 3;
                      blur_size = 8;
                    }
                  ];
                  input-field = [
                    {
                      size = "400, 50";
                      position = "0, -80";
                      monitor = "DP-1";
                      dots_center = true;
                      fade_on_empty = false;
                      font_color = "rgb(202, 211, 245)";
                      inner_color = "rgb(91, 96, 120)";
                      outer_color = "rgb(0, 0, 0)";
                      outline_thickness = 2;
                      placeholder_text = "Enter Password";
                      rounding = 16;
                    }
                  ];
                  label = [
                  {
                  monitor = "DP-1";
                  text = "$USER";
                  font_size = "48";
                  color = "rgb(202, 211, 245)";

                  }
                   {
                     monitor = "DP-1";
                     text = "$TIME";
                     font_size = "72";
                     color = "rgb(202, 211, 245)";
                     valign = "center";
                     halign = "center";
                     position = "0, 0";
                     }
                     {
                        monitor = "DP-1";
                                          text = "Failure Count: $ATTEMPTS";
                                          font_size = "12";
                                          color = "rgba(204, 34, 34, 1.0)";
                                          valign = "bottom";
                                          halign = "right";
                                          position = "-20, 0";

                     }
                  ];
                };

                };
}
