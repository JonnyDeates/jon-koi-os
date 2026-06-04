{
pkgs,
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
          jetbrains.idea
          prusa-slicer
          blender
          antimicrox
          spotify
          (pkgs.symlinkJoin {
            name = "affinity-v3-wrapped";
            paths = [ affinity-v3 ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/affinity-v3 \
                --set WINEDLLOVERRIDES "opencl=d"
            '';
          })
          libreoffice-qt
          hunspell # Spell check for libreoffice
          prismlauncher
          claude-code
          zed-editor-fhs
          mission-center
    ];
    programs = {
        firefox.enable = false;
        java.enable = true;
    };
}
