{
  pkgs,
  config,
  lib,
  inputs,
  username,
  host,
  ...
}:

let
  hyprplugins = inputs.hyprland-plugins.packages.${pkgs.system};
  inherit (import ../../hosts/${host}/variables.nix)
    browser
    terminal
    extraMonitorSettings
    ;
in
with lib;
{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    systemd = {
      enable = true;
      variables = [ "--all" ];
    };
    #plugins = [
      # hyprplugins.hyprtrails
    #];
    extraConfig =
      let
        modifier = "SUPER";
      in
      concatStrings [
        ''
                env = NIXOS_OZONE_WL, 1
                env = NIXPKGS_ALLOW_UNFREE, 1
                env = XDG_CURRENT_DESKTOP, Hyprland
                env = XDG_SESSION_TYPE, wayland
                env = XDG_SESSION_DESKTOP, Hyprland
                env = GDK_BACKEND, wayland, x11
                env = GTK_IM_MODULE=wayland
                env = CLUTTER_BACKEND, wayland
                env = QT_QPA_PLATFORM=wayland;xcb
                env = QT_WAYLAND_DISABLE_WINDOWDECORATION, 1
                env = QT_AUTO_SCREEN_SCALE_FACTOR, 1
                env = SDL_VIDEODRIVER, x11
                env = MOZ_ENABLE_WAYLAND, 1
                env = LD_LIBRARY_PATH, ~/.steam/bin32:/opt/rocm/hip/lib:$LD_LIBRARY_PATH
                env = HIP_VISIBLE_DEICES, 1
                env = HSA_OVERRIDE_GFX_VERSION, 11.0.0
                env = HCC_AMDGPU_TARGET, gfx1100
                env = CUDA_VISIBLE_DEVICES, 1
                env = HSA_ENABLE_SDMA, 0
                env = HYPRCURSOR_THEME,Bibata-Modern-Ice
                env = HYPRCURSOR_SIZE,64
                env = XCURSOR_SIZE,64
                exec-once = dbus-update-activation-environment --systemd --all
                exec-once = systemctl --user import-environment QT_QPA_PLATFORMTHEME WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
                exec-once = killall -q swww;sleep .5 && swww init
                exec-once = killall -q swaync;sleep .5 && swaync
                exec-once = nm-applet --indicator
                exec-once = lxqt-policykit-agent
                exec-once = sleep 2 && hypridle
                exec-once = sleep 1.5 && swww img /home/${username}/Pictures/Wallpapers/jonkoios.png
                exec-once = sleep 2 && wallsetter
                exec-once = sleep 6 && adb kill-server
                monitor=,preferred,auto,1
                ${extraMonitorSettings}
                
                general {
                           gaps_in = 3
                           gaps_out = 6
                           border_size = 2
                           layout = dwindle
                           resize_on_border = true
                           col.active_border = rgb(${config.stylix.base16Scheme.base08}) rgb(${config.stylix.base16Scheme.base0C}) 45deg
                           col.inactive_border = rgb(${config.stylix.base16Scheme.base01})
                         }
                         input {
                           kb_layout = us
                           kb_options = grp:alt_shift_toggle
                           kb_options=caps:super
                           numlock_by_default=true
                           scroll_factor=0.7
                           follow_mouse = 1
                           touchpad {
                             natural_scroll = false
                           }
                           sensitivity = 0 # -1.0 - 1.0, 0 means no modification.
                           accel_profile = flat
                         }
                         windowrule = noborder, title:wofi
                         windowrule = center, title:wofi
                         windowrule = center, title:steam
                         windowrule = float, title:nm-connection-editor
                         windowrule = float, title:blueman-manager
                         windowrule = float, title:swayimg
                         windowrule = float, title:vlc
                         windowrule = float, title:pavucontrol
                         windowrule = float, title:swayimg
                         windowrule = float, title:nwg-look
                         windowrule = float, title:qt5ct
                         windowrule = float, title:mpv
                         windowrule = float, title:zoom
                         windowrule = stayfocused, title:^()$,class:^(steam)$
                         windowrule = minsize 1 1, title:^()$,class:^(steam)$
                         windowrule = opacity 0.9 0.7, class:^(thunar)$

                         gestures {
                           workspace_swipe = true
                           workspace_swipe_fingers = 3
                         }
                         misc {
                            initial_workspace_tracking = 0
                            mouse_move_enables_dpms = true
                            key_press_enables_dpms = false
                         }
                         animations {
                            enabled = yes
                            bezier = wind, 0.05, 0.9, 0.1, 1.05
                            bezier = winIn, 0.1, 1.1, 0.1, 1.1
                            bezier = winOut, 0.3, -0.3, 0, 1
                            bezier = liner, 1, 1, 1, 1
                            animation = windows, 1, 6, wind, slide
                            animation = windowsIn, 1, 6, winIn, slide
                            animation = windowsOut, 1, 5, winOut, slide
                            animation = windowsMove, 1, 5, wind, slide
                            animation = border, 1, 1, liner
                            animation = fade, 1, 10, default
                            animation = workspaces, 1, 5, wind
                         }
                         decoration {
                            rounding = 10
                            blur {
                                enabled = true
                                size = 5
                                passes = 3
                                new_optimizations = on
                                ignore_opacity = off
                            }
                         }
                         plugin {
                           hyprtrails {
                           }
                         }
                         dwindle {
                           pseudotile = true
                           preserve_split = true
                         }
                          bind = ${modifier},Return,exec,${terminal}
                          bind = ${modifier}SHIFT,Return,exec,rofi-launcher
                          bind = ${modifier}SHIFT,W,exec,web-search
                          bind = ${modifier}ALT,W,exec,wallsetter
                          bind = ${modifier}SHIFT,N,exec,swaync-client -rs
                          bind = ${modifier},W,exec,${browser}
                          bind = ${modifier},E,exec,emopicker9000
                          bind = ${modifier},S,exec,screenshootin
                          bind = ${modifier},D,exec,discord
                          bind = ${modifier},O,exec,obs
                          bind = ${modifier},C,exec,hyprpicker -a
                          bind = ${modifier},G,exec,gimp
                          bind = ${modifier}SHIFT,G,exec,godot4
                          bind = ${modifier},T,exec,thunar
                          bind = ${modifier},M,exec,spotify
                          bind = ${modifier},Q,killactive,
                          bind = ${modifier},P,pseudo,
                          bind = ${modifier}SHIFT,I,togglesplit,
                          bind = ${modifier},F,fullscreen,
                          bind = ${modifier}SHIFT,F,togglefloating,
                          bind = ${modifier}SHIFT,left,movewindow,l
                          bind = ${modifier}SHIFT,right,movewindow,r
                          bind = ${modifier}SHIFT,up,movewindow,u
                          bind = ${modifier}SHIFT,down,movewindow,d
                          bind = ${modifier}SHIFT,h,movewindow,l
                          bind = ${modifier}SHIFT,l,movewindow,r
                          bind = ${modifier}SHIFT,k,movewindow,u
                          bind = ${modifier}SHIFT,j,movewindow,d
                          bind = ${modifier},left,movefocus,l
                          bind = ${modifier},right,movefocus,r
                          bind = ${modifier},up,movefocus,u
                          bind = ${modifier},down,movefocus,d
                          bind = ${modifier},h,movefocus,l
                          bind = ${modifier},l,movefocus,r
                          bind = ${modifier},k,movefocus,u
                          bind = ${modifier},j,movefocus,d
                          bind = ${modifier},1,workspace,1
                          bind = ${modifier},2,workspace,2
                          bind = ${modifier},3,workspace,3
                          bind = ${modifier},4,workspace,4
                          bind = ${modifier},5,workspace,5
                          bind = ${modifier},6,workspace,6
                          bind = ${modifier},7,workspace,7
                          bind = ${modifier},8,workspace,8
                          bind = ${modifier},9,workspace,9
                          bind = ${modifier},0,workspace,10
                          bind = ${modifier}SHIFT,SPACE,movetoworkspace,special
                          bind = ${modifier},SPACE,togglespecialworkspace
                          bind = ${modifier}SHIFT,1,movetoworkspace,1
                          bind = ${modifier}SHIFT,2,movetoworkspace,2
                          bind = ${modifier}SHIFT,3,movetoworkspace,3
                          bind = ${modifier}SHIFT,4,movetoworkspace,4
                          bind = ${modifier}SHIFT,5,movetoworkspace,5
                          bind = ${modifier}SHIFT,6,movetoworkspace,6
                          bind = ${modifier}SHIFT,7,movetoworkspace,7
                          bind = ${modifier}SHIFT,8,movetoworkspace,8
                          bind = ${modifier}SHIFT,9,movetoworkspace,9
                          bind = ${modifier}SHIFT,0,movetoworkspace,10
                          bind = ${modifier}CONTROL,right,workspace,e+1
                          bind = ${modifier}CONTROL,left,workspace,e-1
                          bind = ${modifier},mouse_down,workspace, e+1
                          bind = ${modifier},mouse_up,workspace, e-1
                          bindm = ${modifier},mouse:272,movewindow
                          bindm = ${modifier},mouse:273,resizewindow
                          bind = ALT,Tab,cyclenext
                          bind = ALT,Tab,bringactivetotop
                          bind = ,XF86AudioRaiseVolume,exec,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
                          bind = ,XF86AudioLowerVolume,exec,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
                          binde = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
                          bind = ,XF86AudioPlay, exec, playerctl play-pause
                          bind = ,XF86AudioPause, exec, playerctl play-pause
                          bind = ,XF86AudioNext, exec, playerctl next
                          bind = ,XF86AudioPrev, exec, playerctl previous
                          bind = ,XF86MonBrightnessDown,exec,brightnessctl set 5%-
                          bind = ,XF86MonBrightnessUp,exec,brightnessctl set +5%
                       ''
                     ];
                 };
               }

