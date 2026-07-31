{
  description = "Go development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
