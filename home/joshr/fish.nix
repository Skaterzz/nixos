{ pkgs, ... }:

{
  home.packages = with pkgs; [
    eza
    fastfetch
  ];

  programs.fish = {
    enable = true;

    # Upstream config.fish.tmpl sources /usr/share/cachyos-fish-config behind an
    # existence check; that path never exists on NixOS, so it's omitted here.
    interactiveShellInit = ''
    # Base16 Default Dark
       set -g fish_color_normal d8d8d8
       set -g fish_color_command 7cafc2
       set -g fish_color_keyword ba8baf
       set -g fish_color_quote a1b56c
       set -g fish_color_redirection 86c1b9
       set -g fish_color_end ba8baf
       set -g fish_color_error ab4642
       set -g fish_color_param d8d8d8
       set -g fish_color_comment 585858
       set -g fish_color_selection --background=383838
       set -g fish_color_search_match --background=383838
       set -g fish_color_operator 86c1b9
       set -g fish_color_escape 86c1b9
       set -g fish_color_autosuggestion 585858
       set -g fish_color_cwd f7ca88
       set -g fish_color_cwd_root ab4642
       set -g fish_color_user a1b56c
       set -g fish_color_host 7cafc2
       set -g fish_color_valid_path --underline
     
    # pager
       set -g fish_pager_color_progress 585858
       set -g fish_pager_color_prefix 86c1b9
       set -g fish_pager_color_completion d8d8d8
       set -g fish_pager_color_description 585858
       set -g fish_pager_color_selected_background --background=383838
      function fish_greeting
          fastfetch -c ~/.smallfetch.jsonc
      end
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

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };
  xdg.configFile."starship.toml".source = ./files/starship.toml;

  home.file.".smallfetch.jsonc".source = ./files/smallfetch.jsonc;
}
