# The animated space wallpaper, from its own flake (github:JonnyDeates/nix-space-wallpaper). Super+Alt+W
# toggles it (hyprland.nix).
{ inputs, ... }:
{
  imports = [ inputs.space-wallpaper.homeManagerModules.default ];

  services.space-wallpaper = {
    enable = true;
    monitors = [
      "DP-1"
      "DP-2"
      "DP-3"
    ];
    # DP-1 is the main (gaming) monitor; previews go on DP-2.
    preview.output = "DP-2";
  };
}
