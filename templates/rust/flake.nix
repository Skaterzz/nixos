{
  description = "Rust development environment";

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
          # nixpkgs' stable toolchain. For a pinned or nightly one, add the
          # `rust-overlay` flake as an input and take rustc from there.
          cargo
          rustc
          rustfmt
          clippy
          rust-analyzer

          # Most crates that link C libraries need these two to find them.
          pkg-config
        ];

        # rust-analyzer looks for the standard library source here; nixpkgs
        # ships it, but not where the default lookup expects.
        RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

        # Native libraries a crate links against go here, e.g.
        # buildInputs = with pkgs; [ openssl sqlite ];
        buildInputs = [ ];
      };
    };
}
