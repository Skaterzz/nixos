{ ... }:

# tmux, shared by joshr and root. Mirrors the dotfiles' dot_tmux.conf
# (https://github.com/joshrandall8478/dotfiles), which is just `set -g mouse on`.
{
  programs.tmux = {
    enable = true;
    mouse = true;
  };
}
