{ lib, pkgs, ... }:

{
  programs.git = {
    enable = true;
    package = pkgs.gitFull;

    # One `settings` block, which is what `extraConfig` was renamed to. The
    # two were always the same attrset written into the same file, so this is
    # the identity and the credential helpers together rather than a section
    # each.
    settings = {
      user = {
        name = "Joshua Randall";
        email = "josh@joshrandall.net";
      };

      # GitLab credential helper
      "credential \"https://gitlab.com\"" = {
        helper = "!${pkgs.glab}/bin/glab auth git-credential";
      };

      # GitHub credential helpers
      "credential \"https://github.com\"" = {
        helper = "!${pkgs.gh}/bin/gh auth git-credential";
      };

      "credential \"https://gist.github.com\"" = {
        helper = "!${pkgs.gh}/bin/gh auth git-credential";
      };
    };
  };

  # Makes `gh auth login` and `glab auth login` available interactively,
  # including when logged in as root.
  home.packages = [
    pkgs.gh
    pkgs.glab
  ];

  # `git config --global` needs somewhere writable to land.
  #
  # programs.git renders everything above into ~/.config/git/config, and what
  # home-manager writes is a symlink into the store — so the file git would
  # otherwise pick for a --global write is read-only.
  #
  # Which of the two global paths it picks is decided in git_global_config()
  # (config.c): ~/.gitconfig wins whenever it is readable, and only when it is
  # missing does git fall back to the XDG file. With no ~/.gitconfig that
  # fallback is the store symlink, so every --global write fails with EACCES.
  #
  # Which is what stopped `gh auth login` and `glab auth login`. Both offer to
  # set git up for you, and accepting runs
  # `git config --global credential.<host>.helper ...` — that write is what
  # dies, not the login. The tokens were never the problem: they go to
  # ~/.config/gh/hosts.yml and ~/.config/glab-cli/config.yml, and nothing here
  # manages either.
  #
  # An empty ~/.gitconfig flips that choice back, so those writes land in a
  # real file the user owns.
  #
  # Deliberately *not* home.file — the point is that home-manager does not own
  # this one. Created only when absent, so whatever accumulates in it survives
  # rebuilds untouched.
  #
  # Note the precedence that buys: git reads ~/.gitconfig after the XDG file,
  # so anything written there outranks the declarations above. That is the
  # right way round for a user override, but it does mean a stray
  # `git config --global user.email` silently shadows the identity set here
  # rather than failing loudly the way it used to.
  home.activation.writableGitConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.gitconfig" ]; then
      $DRY_RUN_CMD touch "$HOME/.gitconfig"
    fi
  '';
}
