{ username, ... }:

# Home Manager entry point for this host. Shared configuration lives in modules/home.
{
  imports = [ ../../modules/home ];

  home.username = "${username}";
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "23.11";
  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.home-manager.enable = true;
}
