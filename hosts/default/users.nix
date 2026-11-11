{
  pkgs,
  config,
  username,
  host,
  ...
}:

let
  inherit (import ./variables.nix) gitUsername;
in
{
  users.groups.adbusers = { };
  users.users = {
    "${username}" = {
      homeMode = "755";
      isNormalUser = true;
      description = "${gitUsername}";
      extraGroups = [
        "networkmanager"
        "wheel"
        "docker"
        "libvirtd"
        "scanner"
        "gamemode"
        "lp"
        "adbusers"
        "video"
        "plugdev"
        "dialout"
      ];
      shell = pkgs.bash;
      ignoreShellProgramCheck = true;
    };
  };
}
