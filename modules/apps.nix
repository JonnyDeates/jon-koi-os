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
          bettercrewlink
          keymapp
          trilium-next-server
          ledger-live-desktop
          jetbrains.idea
          prusa-slicer
          bambu-studio
          blender
          antimicrox
          spotify
          # affinity-v3 disabled: upstream affinity-nix fetches NetFx64.exe from
          # download.microsoft.com (404) and its Wayback fallback (500). Re-enable
          # once mrshmllow/affinity-nix updates the URL.
          # (pkgs.symlinkJoin {
          #   name = "affinity-v3-wrapped";
          #   paths = [ affinity-v3 ];
          #   buildInputs = [ pkgs.makeWrapper ];
          #   postBuild = ''
          #     wrapProgram $out/bin/affinity-v3 \
          #       --set WINEDLLOVERRIDES "opencl=d"
          #   '';
          # })
          libreoffice-qt
          hunspell # Spell check for libreoffice
          prismlauncher
          claude-code
          zed-editor-fhs
          mission-center
          godot
    ];
    programs = {
        firefox.enable = false;
        java.enable = true;
    };
}
