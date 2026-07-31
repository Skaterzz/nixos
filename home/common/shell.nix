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
