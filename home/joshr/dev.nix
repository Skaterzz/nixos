{ pkgs, ... }:

# Development tooling for both machines, both sessions.
#
# The organising idea is that *nothing language-specific lives here*. Python,
# node, a Rust toolchain and a C compiler all belong to the project that needs
# them, pinned in that project's own flake, entered automatically by direnv
# when you cd into it and gone again when you leave. What's below is only the
# part that has to exist before any of that can happen.
#
# See "Development environments" in the README for the workflow, and
# ../../templates/ for the starting points `dev-init` copies.
let
  # One command to turn an empty directory into a working dev environment.
  #
  # `nix` and `direnv` come from the ambient PATH rather than runtimeInputs on
  # purpose: nix is the system daemon's client and pinning a second copy into
  # this script's closure would be a different nix from the one doing the
  # build, and direnv is installed by the module below — its hook is already
  # in the shell that's calling this.
  devInit = pkgs.writeShellApplication {
    name = "dev-init";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      templates="generic python node rust go"
      flakeRef="''${DEV_TEMPLATES_FLAKE:-github:joshrandall8478/fine-ill-try-nix}"
      template="''${1:-generic}"

      case " $templates " in
        *" $template "*) ;;
        *)
          echo "unknown template: $template" >&2
          echo "usage: dev-init [$(echo "$templates" | tr ' ' '|')]" >&2
          exit 2
          ;;
      esac

      if [ -e flake.nix ]; then
        echo "flake.nix already exists here — refusing to overwrite it." >&2
        echo "Edit it by hand, or run dev-init in a fresh directory." >&2
        exit 1
      fi

      nix flake init -t "$flakeRef#$template"

      # The templates ship an .envrc, but only if the directory was empty of
      # one — nix flake init won't clobber an existing file.
      if [ ! -e .envrc ]; then
        printf 'use flake\n' > .envrc
      fi

      # Marks the .envrc trusted. It doesn't build anything itself — the
      # shell's direnv hook does that at the next prompt, which is the one
      # you get back when this exits.
      direnv allow

      echo
      echo "Ready. Add packages to the devShell in flake.nix; direnv rebuilds"
      echo "and re-enters the shell on save."
    '';
  };
in
{
  # direnv, with nix-direnv underneath it.
  #
  # Plain direnv re-evaluates `use flake` from scratch on every cd, which for
  # a flake means a full evaluation each time — several seconds on anything
  # non-trivial. nix-direnv replaces that with a cached profile and only
  # re-evaluates when flake.nix or flake.lock actually change, which is the
  # difference between this being usable and not.
  #
  # It also plants a GC root in .direnv/, so the weekly `nix-collect-garbage
  # --delete-older-than 14d` in modules/nixos/base.nix can't delete a shell
  # you're still using out from under you.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    # Same reasoning as starship in home/common/shell.nix: stated rather than
    # left to the defaults, so the intent survives a change to
    # home.shell.enableShellIntegration.
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;

    config.global = {
      # direnv otherwise prints every exported variable on entry, which for a
      # nix shell is a screenful of store paths.
      hide_env_diff = true;

      # How long to wait before warning that a shell is slow to build. The
      # default 5s fires constantly on a cold nix build that's working fine.
      warn_timeout = "1m";
    };
  };

  home.packages = [ devInit ] ++ (
    with pkgs;
    [
      # --- nix itself -------------------------------------------------
      nil # language server, for the VS Code Nix extension
      nixfmt-rfc-style # the formatter this flake's `nix fmt` uses
      nix-output-monitor # `nom build` — readable build progress
      nix-tree # what pulled that dependency in
      cachix # binary caches, for projects that publish one

      # --- everyday, language-agnostic --------------------------------
      just # per-project task runner, with no build system attached
      jq
      yq-go
      ripgrep
      fd
      lazygit
      gnumake
    ]
  );
}
