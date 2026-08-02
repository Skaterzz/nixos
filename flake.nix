{
  description = "joshr's gaming + development NixOS workstation (KDE Plasma, NVIDIA, Steam, Docker)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    #nur = {
    #  url = "github:nix-community/NUR";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

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

    #xwayland-satellite-scale-fixes = {
    #  url = "github:larsch/xwayland-satellite/scale-fixes";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

    # joshrandall8478's existing chezmoi dotfiles repo. Used purely as a source
    # of static assets (fonts, custom Plasma themes/look-and-feel packages,
    # cursor theme, custom icons, wallpapers) that are pulled straight into the
    # home-manager profile below instead of being hand-transcribed.
    dotfiles = {
      url = "github:joshrandall8478/dotfiles";
      flake = false;
    };

    # wallhaven.cc's current toplist, as the API's JSON search response. This
    # is the *list*, not the images: home/joshr/wallhaven.nix reads it and
    # downloads the twenty files it names into
    # ~/.local/share/wallpapers/WallhavenFlake.
    #
    # Locking the response is the point of doing it this way. The twenty
    # become a property of flake.lock like every other input — the same
    # twenty on the desk and on the laptop, changing when `nix flake update`
    # says so and not whenever wallhaven's front page moves. Nix caches
    # fetched files for an hour, so re-locking twice in one sitting wants
    # --refresh:
    #
    #     nix flake update --refresh wallhaven-toplist
    #
    # `file+https` rather than plain https: the plain form is the tarball
    # fetcher, which would try to unpack a JSON document. The query is the
    # website's Toplist view — all three categories (111), SFW only (100),
    # ranked over the last month, nothing below 1080p. Edit it and re-lock to
    # change what "top 20" means; the count itself is
    # `local.wallhaven.count`.
    #
    # `ratios` keeps it to widescreen. Both displays on the desk are 16:9
    # (2560x1440 and 1920x1080, see home/joshr/displays/gamestation.nix), so
    # 16:10 is the widest miss worth accepting — it scales to 16:9 losing a
    # sliver off the top and bottom. Anything squarer arrives pillarboxed or
    # cropped hard by whichever of awww or Plasma is drawing it. The laptop
    # panel isn't pinned anywhere in here (displays/laptop.nix is empty on
    # purpose), so it isn't what this is measured against; 16:10 covers it
    # if it turns out to be one.
    #
    # The parameter takes a comma-separated list, written `%2C` here so the
    # separator survives whatever Nix does to the query on its way to the
    # fetcher — wallhaven url-decodes it back either way. wallhaven also has
    # a `landscape` supergroup, but that is every non-portrait ratio it knows
    # — 4x3 and 5x4 included — which is "not portrait" rather than "wide".
    # The ultrawide ratios (21x9, 32x9) are left out on purpose: nothing
    # here has a display to put them on, and on a 16:9 panel they letterbox
    # to a strip.
    #
    # Narrowing the query narrows the pool it is drawn from, so a month with
    # an unusually vertical toplist can return fewer than
    # `local.wallhaven.count` images. That is handled — the sync script takes
    # what is there — it just means the folder is occasionally short.
    wallhaven-toplist = {
      url = "file+https://wallhaven.cc/api/v1/search?categories=111&purity=100&sorting=toplist&topRange=1M&order=desc&atleast=1920x1080&ratios=16x9%2C16x10";
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
          # `homeModules` is the host's home-manager users, as
          # `username -> entrypoint`. root is added to every host below rather
          # than named in each call: it gets the same fish + starship setup
          # everywhere, minus everything graphical, so there is nothing
          # per-host to say about it.
          mkHost =
            { hostModule, homeModules }:
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
                  # Each account has to exist on the NixOS side as well —
                  # home-manager reads its home directory from
                  # `users.users.<name>` — which is modules/nixos/users.nix,
                  # imported by every host.
                  home-manager.users = nixpkgs.lib.mapAttrs (_name: import) (
                    { root = ./home/root/home.nix; } // homeModules
                  );
                }
              ];
            };
        in
        {
          # --- Plasma sessions -------------------------------------------
          gamestation = mkHost {
            hostModule = ./hosts/gamestation/configuration.nix;
            homeModules = {
              joshr = ./home/joshr/gamestation.nix;
              # raiden = ./home/raiden/gamestation.nix;
              amandak = ./home/amandak/gamestation.nix;
            };
          };

          laptop = mkHost {
            hostModule = ./hosts/laptop/configuration.nix;
            homeModules = {
              joshr = ./home/joshr/laptop.nix;
              # raiden = ./home/raiden/laptop.nix;
              amandak = ./home/amandak/laptop.nix;
            };
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
            homeModules = {
              joshr = ./home/joshr/gamestation-niri.nix;
              # raiden = ./home/raiden/gamestation-niri.nix;
              amandak = ./home/amandak/gamestation-niri.nix;
            };
          };

          laptop-niri = mkHost {
            hostModule = ./hosts/laptop-niri/configuration.nix;
            homeModules = {
              joshr = ./home/joshr/laptop-niri.nix;
              delta = ./home/delta/laptop-niri.nix;
              # raiden = ./home/raiden/laptop-niri.nix;
              amandak = ./home/amandak/laptop-niri.nix;
            };
          };

          # --- headless --------------------------------------------------
          # No desktop at all. Scheduled work lives in its `local.cron`
          # section; see modules/nixos/cron.nix.
          server = mkHost {
            hostModule = ./hosts/server/configuration.nix;
            homeModules = {
              joshr = ./home/joshr/server.nix;
            };
          };
        };

      # Starting points for per-project development environments:
      #
      #   nix flake init -t github:joshrandall8478/nixos#python
      #
      # or `dev-init python`, which does that and sets up direnv in one go.
      # See "Development environments" in MANUAL.md.
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

      # Same program as `nixfmt-rfc-style`, under its own name. nixpkgs used
      # to carry two formatters — that one and a `nixfmt-classic` — and the
      # long name distinguished them; classic has since been removed and
      # `nixfmt-rfc-style` is now an alias that warns on every evaluation.
      formatter.${system} = pkgs.nixfmt;
    };
}
