{ pkgs, ... }:

{
  home.packages = with pkgs; [
    eza
    fastfetch
  ];

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
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
