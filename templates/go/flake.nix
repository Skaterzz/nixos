{
  description = "Go development environment";

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
          go
          gopls
          gotools # goimports and friends
          golangci-lint
        ];

        shellHook = ''
          # Keep the module cache and `go install` output inside the project
          # rather than in ~/go, so removing the directory removes the lot.
          export GOPATH="$PWD/.go"
          export PATH="$GOPATH/bin:$PATH"
        '';
      };
    };
}
