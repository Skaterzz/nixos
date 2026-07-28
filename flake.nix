{
  description = "joshr's gaming + development NixOS workstation (KDE Plasma, NVIDIA, Steam, Docker)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # joshrandall8478's existing chezmoi dotfiles repo. Used purely as a source
    # of static assets (fonts, custom Plasma themes/look-and-feel packages,
    # cursor theme, custom icons, wallpapers) that are pulled straight into the
    # home-manager profile below instead of being hand-transcribed.
    dotfiles = {
      url = "github:joshrandall8478/dotfiles";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, home-manager, plasma-manager, dotfiles, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.gamestation = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/gamestation/configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ];
            home-manager.users.joshr = import ./home/joshr/home.nix;
          }
        ];
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
