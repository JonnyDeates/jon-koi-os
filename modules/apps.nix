{
pkgs,
affinity-nix,
...
}: {
nixpkgs.config = {
  allowUnfree = true;
  };
  environment.systemPackages =
    with pkgs; [
          discord
          keepassxc
          obs-studio
          audacity
          r2modman
          keymapp
          legendary-gl
          ledger-live-desktop
          jetbrains.idea-ultimate
          prusa-slicer
          blender
          antimicrox
          spotify
          affinity-nix.packages.x86_64-linux.photo
    ];

    programs = {
        firefox.enable = true;
        java.enable = true;
    };
}