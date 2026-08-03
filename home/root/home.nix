{ ... }:

# Minimal home profile for root: fish and starship, nothing else.
#
# This mirrors what the dotfiles already do for root. Their `.chezmoiignore`
# has a `root`/`jrh`/`jrp` branch that strips the Plasma configs, Code,
# spicetify, mpv, vlc, wallpapers, icons and colour schemes — leaving the
# shell config and starship. There is no desktop session running as root, so
# none of that would do anything anyway.
#
# The one behavioural difference from joshr, also taken from the dotfiles:
# root's fish_greeting is empty rather than running fastfetch.
{
  imports = [
    ../common/options.nix
    ../common/shell.nix
    ../common/git.nix
    ../common/tmux.nix
    ../common/btop.nix
  ];

  home.username = "root";
  home.homeDirectory = "/root";
  home.stateVersion = "24.11";

  local.shell.fastfetchGreeting = false;

  programs.home-manager.enable = true;

  programs.git = {
    settings.user = {
      name = "Joshua Randall";
      email = "josh@joshrandall.net"; # adjust if this isn't your git identity
    };
  };
}
