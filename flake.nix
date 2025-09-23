{
  description = "JonKoiOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    affinity-nix.url = "github:mrshmllow/affinity-nix";
    #hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    #hyprland-plugins = {
    #  url = "github:hyprwm/hyprland-plugins";
    #  inputs.hyprland.follows = "hyprland";
    #};
    sddm-sugar-candy-nix = {
        url = "gitlab:Zhaith-Izaliel/sddm-sugar-candy-nix";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
   { nixpkgs, home-manager, affinity-nix, sddm-sugar-candy-nix, ... }@inputs:
    let
      system = "x86_64-linux";
      host = "default";
      username = "jonkoi";

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
          overlays = [
            sddm-sugar-candy-nix.overlays.default
          ];
      };
    in
    {
      nixosConfigurations = {
        "${host}" = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit system;
            inherit inputs;
            inherit username;
            inherit affinity-nix;
            inherit host;
          };
          modules = [
            ./hosts/${host}/config.nix
            sddm-sugar-candy-nix.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = {
                inherit system;
                inherit username;
                inherit inputs;
                inherit host;
              };
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.${username} = import ./hosts/${host}/home.nix;
            }
          ];
        };
      };
    };
}
