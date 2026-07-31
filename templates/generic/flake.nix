{
  description = "Development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      # One system, stated plainly. Add more by mapping over a list if this
      # project ever has to build somewhere else.
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        # Everything this project needs to build and run. `nix search nixpkgs
        # <name>` finds the attribute for a given tool.
        packages = with pkgs; [
          # git
          # gnumake
        ];

        # Runs on every entry into the shell — direnv included, so keep it
        # quiet and fast.
        shellHook = ''
          echo "dev shell: $(basename "$PWD")"
        '';

        # Variables the project needs. These leave with the shell.
        # env.DATABASE_URL = "postgres://localhost/dev";
      };
    };
}
