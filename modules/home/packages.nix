{
  pkgs,
  username,
  host,
  ...
}:

# The repo's own scripts (pkgs/) plus a few user packages.
{
  home.packages = [
    (import ../../pkgs/emoji-picker.nix { inherit pkgs; })
    (import ../../pkgs/task-waybar.nix { inherit pkgs; })
    (import ../../pkgs/nvidia-offload.nix { inherit pkgs; })
    (import ../../pkgs/web-search.nix { inherit pkgs; })
    (import ../../pkgs/rofi-launcher.nix { inherit pkgs; })
    (import ../../pkgs/screenshootin.nix { inherit pkgs; })
    (import ../../pkgs/list-hypr-bindings.nix {
      inherit pkgs;
      inherit host;
    })
    (import ../../pkgs/ai-renamer.nix { inherit pkgs; })
    (import ../../pkgs/system-settings.nix { inherit pkgs; })
    (import ../../pkgs/vaultwarden-backup.nix {
      inherit pkgs;
      inherit username;
    })
    (import ../../pkgs/zed-open.nix { inherit pkgs; })
    (import ../../pkgs/lot-map-window.nix { inherit pkgs; })
    (import ../system/discipline/shutdown-postpone.nix { inherit pkgs; })
    pkgs.python3
  ];
}
