{
  description = "Python development environment";

  # `nixpkgs`, not `github:NixOS/nixpkgs/nixos-unstable`: an indirect ref,
  # resolved through the flake registry, which modules/nixos/development.nix
  # points at the exact rev this machine is built from. The store paths that
  # come out of it are the ones already in /nix/store, so the first
  # `direnv allow` has nothing to fetch. Spelled as a URL, a project locks
  # against whatever nixos-unstable is that afternoon and re-downloads a
  # whole second stdenv to say the same thing.
  #
  # It's also what makes the claim in this flake's parent true — that the
  # machines and the shells they build move on one `nix flake update`.
  #
  # On a machine without that registry entry it falls back to the global one
  # (nixpkgs-unstable) and still works. Either way the answer lands in
  # flake.lock, so the project stays reproducible for whoever clones it.
  inputs.nixpkgs.url = "nixpkgs";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # The interpreter this project runs on. Every minor version's
      # *interpreter* is built by Hydra and comes out of the binary cache, so
      # changing this line is free.
      #
      # Its *library set* is not free, and that distinction is the whole
      # reason this file looks the way it does. nixpkgs only builds the
      # Python package sets it marks `recurseIntoAttrs` in all-packages.nix —
      # today python313Packages and python314Packages, the latter being the
      # default `python3Packages`. Every other set (python311Packages,
      # python312Packages, python315Packages) evaluates perfectly well and is
      # simply never built by Hydra, so none of it is in cache.nixos.org and
      # every one of its derivations is compiled locally, test suites and
      # all.
      #
      # 3.13 is the default here because it's on the built list, which keeps
      # `python.withPackages` cheap as well. Moving to `pkgs.python3` (3.14)
      # is equally cheap. Moving to an older one costs nothing *by itself* —
      # see the note on pylsp below for the part that used to make it
      # expensive — but check the list before asking that set for a library.
      python = pkgs.python313;

      # The language server, taken from the default package set on purpose
      # rather than from `python` above.
      #
      # This is the line that made the template slow. It used to read
      # `python.pkgs.python-lsp-server` with `python = pkgs.python312`, and
      # python312Packages lost its `recurseIntoAttrs` upstream in November
      # 2025 — so from that day on, entering this shell meant building pylsp
      # from source, and with it every one of its check inputs: numpy,
      # pandas, matplotlib, and the full optional-linter set (pylint, rope,
      # black, yapf, autopep8, flake8, ...). Minutes of compiling, on a first
      # `cd` into the project and again after every `nix flake update`.
      #
      # Decoupling the two costs nothing. pylsp is a tool this project never
      # imports, and jedi resolves completions from $VIRTUAL_ENV — the venv
      # the shellHook activates — rather than from the interpreter pylsp
      # itself happens to be running on, so it reads a 3.12 project correctly
      # while running on 3.14. The version above stays a free choice.
      pylsp = pkgs.python3Packages.python-lsp-server;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          python
          pkgs.uv # resolver and venv manager; `pip` also works
          pkgs.ruff # linter + formatter
          pylsp
        ];

        # Point uv at the interpreter above and stop it reaching for its own.
        # Left alone, uv downloads a standalone CPython the first time it
        # wants one — a fetch on the critical path, and a different Python
        # from the one pinned here, which rather defeats pinning it.
        env = {
          UV_PYTHON = "${python}/bin/python";
          UV_PYTHON_DOWNLOADS = "never";
        };

        shellHook = ''
          # A venv, so pip/uv installs land in the project rather than trying
          # to write into the read-only store. Nix supplies the interpreter;
          # PyPI supplies the libraries.
          #
          # If you'd rather have every dependency come from nixpkgs instead,
          # delete this hook and list them as `python.withPackages (ps: [
          # ps.requests ps.numpy ])` in packages above — reading the note on
          # built package sets by `python` first.
          #
          # Rebuilt when it doesn't answer with the interpreter above. A venv
          # records an absolute path to the Python that made it, so once that
          # store path moves — `nix flake update`, or the weekly
          # nix-collect-garbage in base.nix taking the old one with it — a
          # venv left in place fails every command with a missing loader
          # rather than with anything that explains itself. An empty left-hand
          # side is the no-venv-yet case and the broken case at once.
          #
          # A venv that already answers correctly is left entirely alone,
          # which is the point of comparing rather than just rebuilding: `rm
          # -rf` here only ever runs on one that couldn't be used anyway.
          if [ "$(.venv/bin/python -V 2>/dev/null)" != "$(${python}/bin/python -V)" ]; then
            rm -rf .venv
            uv venv --python "${python}/bin/python" .venv
          fi
          source .venv/bin/activate
        '';
      };
    };
}
