{
  config,
  lib,
  pkgs,
  ...
}:

# Shell environment shared by joshr and root, ported from the dotfiles'
# dot_config/fish/config.fish.tmpl and dot_config/starship.toml.
#
# That template branches on username: root gets an empty fish_greeting while
# everyone else gets the fastfetch one. Reproduced here via
# `local.shell.fastfetchGreeting`.
let
  # The two branches of the {{ if eq .chezmoi.username "root" }} block in
  # config.fish.tmpl, kept as whole functions so they read the same way.
  fishGreeting =
    if config.local.shell.fastfetchGreeting then
      ''
        function fish_greeting
            fastfetch -c ~/.smallfetch.jsonc
        end
      ''
    else
      ''
        function fish_greeting
        end
      '';
in
{
  home.packages = [ pkgs.eza ] ++ lib.optional config.local.shell.fastfetchGreeting pkgs.fastfetch;

  programs.fish = {
    enable = true;

    # Upstream config.fish.tmpl sources /usr/share/cachyos-fish-config behind an
    # existence check; that path never exists on NixOS, so it's omitted here.
    interactiveShellInit = ''
      # Exact fish_config "Base16 Eighties" preset.
      set -g fish_color_normal --reset
      set -g fish_color_autosuggestion 747369
      set -g fish_color_cancel -r
      set -g fish_color_command 99cc99
      set -g fish_color_comment ffcc66
      set -g fish_color_cwd green
      set -g fish_color_cwd_root red
      set -g fish_color_end cc99cc
      set -g fish_color_error f2777a
      set -g fish_color_escape 66cccc
      set -g fish_color_history_current --bold
      set -g fish_color_host --reset
      set -g fish_color_host_remote yellow
      set -e fish_color_keyword
      set -g fish_color_operator 6699cc
      set -e fish_color_option
      set -g fish_color_param d3d0c8
      set -g fish_color_quote ffcc66
      set -g fish_color_redirection d3d0c8
      set -g fish_color_search_match white --background=brblack --bold
      set -g fish_color_selection white --background=brblack --bold
      set -g fish_color_status red
      set -g fish_color_user brgreen
      set -g fish_color_valid_path --underline

      set -g fish_pager_color_completion --reset
      set -g fish_pager_color_description B3A06D yellow
      set -g fish_pager_color_prefix --bold --underline
      set -g fish_pager_color_progress brwhite --background=cyan --bold
      set -g fish_pager_color_selected_background --background=brblack

      # overwrite greeting
      # potentially disabling fastfetch
      ${fishGreeting}
    '';

    functions = {
      ls = {
        description = "eza as ls";
        body = "eza --group-directories-first --icons=auto $argv";
      };
      ll = {
        description = "long list";
        body = "eza -l --group-directories-first --icons=auto --git $argv";
      };
      la = {
        description = "long list, all files";
        body = "eza -la --group-directories-first --icons=auto --git $argv";
      };
      lt = {
        description = "tree view";
        body = "eza --tree --level=2 --icons=auto --group-directories-first $argv";
      };
      lg = {
        description = "long list with git status";
        body = "eza -l --git --git-repos --icons=auto --group-directories-first $argv";
      };

      # On-demand version of the weekly sweep in modules/nixos/base.nix, for
      # when you want the space back now or want a different cutoff than the
      # timer's 7d. Shared by joshr and root, hence the id check below.
      #
      # Two runs, not one, and that's the whole reason this is a function
      # rather than an abbreviation. `nix-collect-garbage` only walks the
      # profiles it can see, and "which profiles" follows $HOME: the sudo run
      # gets the system profile — every old kernel, initrd and system closure,
      # which is where the space actually is — but root's HOME is /root, so it
      # never sees ~/.local/state/nix/profiles, where home-manager keeps
      # joshr's generations. Run only the sudo half and those stay pinned as
      # live GC roots, taking their whole closures with them.
      #
      # Nothing here touches the current generation: --delete-older-than and
      # -d both keep it. What they do cost is rollback — the boot menu is the
      # recovery path for a bad switch (see "Rebuilding after changes" in
      # MANUAL.md), so `nix-clean all` is deliberately something you have to ask
      # for by name rather than the default.
      nixos-cd = {
        description = "sudo and cd to /etc/nixos";
        body = ''
        cd /etc/nixos
        sudo -s
        '';
      };
      nix-clean = {
        description = "delete nix generations older than <age>, default 7d ('all' for every old one)";
        body = ''
          set -l age $argv[1]
          test -z "$age"; and set age 7d

          # The cutoff is spelled out at each call site rather than held in a
          # variable: `set -l cutoff --delete-older-than $age` would hand
          # `set` a value starting with a dash, which it reads as its own
          # option.
          echo "Deleting system generations ($age)…"
          if test "$age" = all
              sudo nix-collect-garbage -d
          else
              sudo nix-collect-garbage --delete-older-than "$age"
          end

          if test $status -ne 0
              echo "nix-collect-garbage failed; stopping here." >&2
              return 1
          end

          # Already covered by the run above when this *is* root.
          if test (id -u) -ne 0
              echo "Deleting home-manager generations ($age)…"
              if test "$age" = all
                  nix-collect-garbage -d
              else
                  nix-collect-garbage --delete-older-than "$age"
              end

              if test $status -ne 0
                  echo "System generations were cleaned, home-manager's were not." >&2
                  return 1
              end
          end

          echo
          echo "Deleted generations are still listed in the boot menu."
          echo "Prune it with: sudo nixos-rebuild boot --flake /etc/nixos#<host>"
          echo "<host> is the flake attribute (gamestation, usb, server…),"
          echo "which is not this machine's hostname."
        '';
      };

      # nix-clean by count rather than by age: keep the newest N generations,
      # delete everything below them, then sweep. Same two-profile split and
      # the same boot-menu caveat as nix-clean above — see that comment.
      #
      # The deleting is left to `nix-env --delete-generations +N`, which is the
      # only part of this that has to be exactly right. Its rule is "keep N
      # counting back from the *current* generation, and never touch the
      # current one or anything above it", so a machine sitting on a rollback
      # doesn't lose the newer generations it would roll forward to.
      #
      # The arithmetic below only builds the preview, and deliberately mirrors
      # that same rule so the list shown is the list deleted: generations are
      # listed oldest-first, so with the current one at position `cur`, the
      # doomed ones are exactly the first `cur - N`. Parsing --list-generations
      # is what makes the preview possible at all; --dry-run would be the other
      # way, but its output wording is not something to depend on.
      nix-delete-gens = {
        description = "delete nix generations, keeping the newest <count> (default 10)";
        body = ''
          set -l keep $argv[1]
          test -z "$keep"; and set keep 10

          # Anything that isn't a positive integer would either be rejected by
          # nix-env further down or, worse, quietly change what gets deleted.
          if not string match -qr '^[1-9][0-9]*$' -- $keep
              echo "nix-delete-gens: keep count must be a positive whole number, got '$keep'." >&2
              return 1
          end

          set -l system /nix/var/nix/profiles/system
          set -l hm ~/.local/state/nix/profiles/home-manager

          # Reading the profile doesn't need root; only the deletion does.
          set -l listing (nix-env -p $system --list-generations)
          if test $status -ne 0
              echo "nix-delete-gens: could not list the system profile's generations." >&2
              return 1
          end

          set -l cur 0
          for i in (seq (count $listing))
              if string match -qr '\(current\)\s*$' -- $listing[$i]
                  set cur $i
              end
          end
          if test $cur -eq 0
              echo "nix-delete-gens: no generation is marked (current); refusing to guess." >&2
              return 1
          end

          set -l ndoomed (math $cur - $keep)
          if test $ndoomed -lt 1
              echo "Nothing to delete: "(count $listing)" system generations, and the newest $keep are staying."
              return 0
          end

          set -l gens (string match -rg '^\s*(\d+)' -- $listing)

          echo "Deleting these $ndoomed system generations, keeping the newest $keep:"
          printf '  %s\n' $gens[1..$ndoomed]
          echo

          read -l -P "Proceed, then collect garbage? [y/N] " reply
          if not string match -qir '^y(es)?$' -- $reply
              echo "Aborted; nothing was deleted."
              return 1
          end

          sudo nix-env -p $system --delete-generations +$keep
          if test $status -ne 0
              echo "Deleting system generations failed; stopping here." >&2
              return 1
          end

          # Already covered by the sudo run when this *is* root.
          if test (id -u) -ne 0; and test -e $hm
              echo "Trimming home-manager to its newest $keep generations…"
              nix-env -p $hm --delete-generations +$keep
              if test $status -ne 0
                  echo "System generations went, home-manager's did not." >&2
                  return 1
              end
          end

          # Deleting a generation only unlinks it; the closure it was holding
          # down isn't space back until something collects it.
          echo "Collecting garbage…"
          sudo nix-collect-garbage
          if test $status -ne 0
              echo "Generations were deleted, but garbage collection failed." >&2
              return 1
          end
          if test (id -u) -ne 0
              nix-collect-garbage
              if test $status -ne 0
                  echo "The system profile was swept, home-manager's was not." >&2
                  return 1
              end
          end

          echo
          echo "Deleted generations are still listed in the boot menu."
          echo "Prune it with: sudo nixos-rebuild boot --flake /etc/nixos#<host>"
          echo "<host> is the flake attribute (gamestation, usb, server…),"
          echo "which is not this machine's hostname."
        '';
      };
    };
  };

  # Fish is the login shell, but zsh/bash/nushell all get the same prompt.
  #
  # Both halves below are needed. starship's enable*Integration options
  # already default to true (via home.shell.enableShellIntegration), but all
  # they do is set `programs.<shell>.initExtra`-style options — and
  # home-manager only writes a shell's rc file when that shell's own module is
  # enabled. Without these, the zsh/bash/nushell integrations are computed and
  # then dropped on the floor.
  programs.bash.enable = true;
  programs.zsh.enable = true;
  programs.nushell.enable = true;

  programs.starship = {
    enable = true;
    # Stated explicitly rather than leaning on the defaults, so the intent
    # survives a change to home.shell.enableShellIntegration.
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
  };

  # One config for every shell. starship looks here by default, and
  # home-manager also exports STARSHIP_CONFIG pointing at it.
  xdg.configFile."starship.toml".source = ./files/starship.toml;

  # Only useful when the greeting actually calls fastfetch.
  home.file.".smallfetch.jsonc" = lib.mkIf config.local.shell.fastfetchGreeting {
    source = ./files/smallfetch.jsonc;
  };
}
