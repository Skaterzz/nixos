{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    package = pkgs.gitFull;

    settings.user = {
      name = "Joshua Randall";
      email = "josh@joshrandall.net";
    };

    extraConfig = {
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
}
