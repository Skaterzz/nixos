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

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
    {
      self,
      nixpkgs,
      home-manager,
      plasma-manager,
      spicetify-nix,
      dotfiles,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations =
        let
          mkHost =
            { hostModule, homeModule }:
            nixpkgs.lib.nixosSystem {
              inherit system;
              specialArgs = { inherit inputs; };
              modules = [
                hostModule

                home-manager.nixosModules.home-manager
                {
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  # home-manager refuses to overwrite a file it doesn't already
                  # manage. Now that it writes ~/.bashrc and ~/.zshrc, any
                  # pre-existing copy would abort activation; this moves them
                  # aside as e.g. ~/.bashrc.hm-backup instead.
                  home-manager.backupFileExtension = "hm-backup";
                  home-manager.extraSpecialArgs = { inherit inputs; };
                  home-manager.sharedModules = [
                    plasma-manager.homeModules.plasma-manager
                    spicetify-nix.homeManagerModules.spicetify
                  ];
                  home-manager.users.joshr = import homeModule;
                  # root gets the same fish + starship setup, minus everything
                  # graphical. Same on every host, so it isn't parameterised.
                  home-manager.users.root = import ./home/root/home.nix;
                }
              ];
            };
        in
        {
          # --- Plasma sessions -------------------------------------------
          gamestation = mkHost {
            hostModule = ./hosts/gamestation/configuration.nix;
            homeModule = ./home/joshr/gamestation.nix;
          };

          laptop = mkHost {
            hostModule = ./hosts/laptop/configuration.nix;
            homeModule = ./home/joshr/laptop.nix;
          };

          # --- niri sessions ---------------------------------------------
          # Same two machines, niri instead of Plasma. Separate hosts because
          # the two use different display managers (plasma-login-manager vs
          # SDDM) and NixOS won't enable both. Switching is just a rebuild:
          #
          #   sudo nixos-rebuild switch --flake .#gamestation-niri
          #   sudo nixos-rebuild switch --flake .#gamestation
          gamestation-niri = mkHost {
            hostModule = ./hosts/gamestation-niri/configuration.nix;
            homeModule = ./home/joshr/gamestation-niri.nix;
          };

          laptop-niri = mkHost {
            hostModule = ./hosts/laptop-niri/configuration.nix;
            homeModule = ./home/joshr/laptop-niri.nix;
          };

          # --- headless --------------------------------------------------
          # No desktop at all. Scheduled work lives in its `local.cron`
          # section; see modules/nixos/cron.nix.
          server = mkHost {
            hostModule = ./hosts/server/configuration.nix;
            homeModule = ./home/joshr/server.nix;
          };
        };

      # Starting points for per-project development environments:
      #
      #   nix flake init -t github:joshrandall8478/fine-ill-try-nix#python
      #
      # or `dev-init python`, which does that and sets up direnv in one go.
      # See "Development environments" in the README.
      #
      # They live here rather than in a separate repo so that the machines
      # and the shells they build are updated by the same `nix flake update`.
      templates = {
        default = self.templates.generic;

        generic = {
          path = ./templates/generic;
          description = "Empty devShell skeleton — add packages and go";
          welcomeText = ''
            Edit the `packages` list in flake.nix, then `direnv allow`.
          '';
        };

        python = {
          path = ./templates/python;
          description = "Python 3.12 with uv, ruff and a project-local venv";
          welcomeText = ''
            Nix supplies the interpreter and tooling; the venv created by the
            shellHook supplies the libraries. `direnv allow` to enter.
          '';
        };

        node = {
          path = ./templates/node;
          description = "Node.js 22 with pnpm and the TypeScript language server";
          welcomeText = ''
            `direnv allow` to enter. npm's global prefix is redirected into
            the project, so `npm i -g` works.
          '';
        };

        rust = {
          path = ./templates/rust;
          description = "Rust toolchain from nixpkgs, with rust-analyzer and clippy";
          welcomeText = ''
            `direnv allow` to enter. Native libraries your crates link
            against go in `buildInputs`.
          '';
        };

        go = {
          path = ./templates/go;
          description = "Go with gopls, gotools and golangci-lint";
          welcomeText = ''
            `direnv allow` to enter. GOPATH is redirected into the project.
          '';
        };
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
