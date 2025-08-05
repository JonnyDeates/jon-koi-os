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
          brave
          discord
          keepassxc
          obs-studio
          audacity
          r2modman
          keymapp
          trilium-next-server
          ledger-live-desktop
          jetbrains.idea-ultimate
          prusa-slicer
          blender
          antimicrox
          spotify
          affinity-nix.packages.x86_64-linux.photo
          libreoffice-qt
          hunspell # Spell check for libreoffice
    ];

    programs = {
        firefox.enable = false;
        java.enable = true;
    };
}