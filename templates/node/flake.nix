{
  description = "Node.js development environment";

  # An indirect ref, resolved through the flake registry, which
  # modules/nixos/development.nix pins to the exact rev this machine is built
  # from — so the shell resolves to store paths that are already here and the
  # first `direnv allow` fetches nothing. Anywhere else it falls back to the
  # global registry entry and still works; either way flake.lock records the
  # answer. See templates/python/flake.nix for the longer version.
  inputs.nixpkgs.url = "nixpkgs";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs_22
          pnpm # swap for `yarn`, or drop it and use the bundled npm
          typescript-language-server
        ];

        shellHook = ''
          # npm's global prefix, kept inside the project. Without this,
          # `npm i -g` tries to write into the store and fails.
          export NPM_CONFIG_PREFIX="$PWD/.npm-global"
          export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
        '';
      };
    };
}
