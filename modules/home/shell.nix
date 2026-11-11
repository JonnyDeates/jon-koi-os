{
  pkgs,
  lib,
  host,
  ...
}:

let
  inherit (import ../../hosts/${host}/variables.nix) gitUsername gitEmail;
in
{
  programs = {
    git = {
      enable = true;
      settings = {
        user = {
          name = "${gitUsername}";
          email = "${gitEmail}";
        };
        core = {
          editor = "vim";
        };
      };
    };
    gh.enable = true;
    btop = {
      enable = true;
      settings = {
        vim_keys = true;
      };
    };
    kitty = {
      enable = true;
      package = pkgs.kitty;
      settings = {
        scrollback_lines = 2000;
        wheel_scroll_min_lines = 1;
        window_padding_width = 4;
        confirm_os_window_close = 0;
      };
      extraConfig = ''
        tab_bar_style fade
        tab_fade 1
        active_tab_font_style   bold
        inactive_tab_font_style bold
      '';
    };
    starship = {
      enable = true;
      package = pkgs.starship;
    };
    bash = {
      enable = true;
      enableCompletion = true;
      initExtra = lib.mkAfter ''
        fastfetch
        if [ -f $HOME/.bashrc-personal ]; then
          source $HOME/.bashrc-personal
        fi
      '';
    };
  };
}
