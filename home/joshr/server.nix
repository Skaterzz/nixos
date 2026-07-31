{ ... }:

# joshr's home profile on the server.
#
# Deliberately not built on ./home.nix. That file is the *desktop* base —
# kitty, VS Code, ranger, spicetify, Firefox, Discord, OBS, a cursor theme,
# fonts pulled from the dotfiles repo — none of which a headless machine has
# any use for, and all of which it would still build and copy into the store.
#
# So this is the same shape as home/root/home.nix: the shared shell and
# nothing else. If something turns out to be genuinely wanted over SSH, add
# it here rather than reaching for ./home.nix.
{
  imports = [
    ../common/options.nix
    ../common/shell.nix
  ];

  home.username = "joshr";
  home.homeDirectory = "/home/joshr";

  # Do not bump this after the initial install; see the Home Manager manual.
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "Joshua Randall";
      email = "josh@joshrandall.net";
    };
  };

  # The fastfetch greeting is a desktop flourish and this is a machine you
  # land on over SSH, often to run one command. `local.shell.fastfetchGreeting
  # = true` if you'd rather have it.
  local.shell.fastfetchGreeting = false;
}
