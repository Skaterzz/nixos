{
  description = "Python development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Change the minor version here and every tool below follows it.
      python = pkgs.python312;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          python
          pkgs.uv # resolver and venv manager; `pip` also works
          pkgs.ruff # linter + formatter
          python.pkgs.python-lsp-server
        ];

        shellHook = ''
          # A venv, so pip/uv installs land in the project rather than trying
          # to write into the read-only store. Nix supplies the interpreter;
          # PyPI supplies the libraries.
          #
          # If you'd rather have every dependency come from nixpkgs instead,
          # delete this hook and list them as `python.withPackages (ps: [
          # ps.requests ps.numpy ])` in packages above.
          if [ ! -d .venv ]; then
            uv venv .venv
          fi
          source .venv/bin/activate
        '';
      };
    };
}
