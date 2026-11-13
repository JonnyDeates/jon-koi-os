{
  description = "JonKoiOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    affinity-nix.url = "github:mrshmllow/affinity-nix";
    openclaude-flake.url = "github:JonnyDeates/openclaude-flake";
    space-wallpaper.url = "github:JonnyDeates/nix-space-wallpaper";
    space-wallpaper.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      affinity-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      host = "default";
      username = "jonkoi";

      unstable-overlay =
        final: prev:
        let
          unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          bambu-studio = unstable.bambu-studio;
          r2modman = unstable.r2modman;
          claude-code = unstable.claude-code;
        };
    in
    {
      nixosConfigurations = {
        "${host}" = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit system;
            inherit inputs;
            inherit username;
            inherit host;
          };
          modules = [
            {
              nixpkgs.overlays = [
                affinity-nix.overlays.default
                (import ./overlays/bettercrewlink.nix)
                unstable-overlay
              ];
            }
            ./hosts/${host}/config.nix
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
