{ ... }:

# sabom — Michael Sabo.
#
# There is no profile here. Each entrypoint next to this file imports the
# matching one from home/joshr/, which is what pulls in the desktop base, the
# session, and everything under home/common/; this file only says which
# account is wearing it. Anything added to joshr's profile therefore arrives
# here too, which is the point of importing rather than copying — including
# the choice of desktop shell, so this account runs noctalia on the two niri
# hosts exactly as joshr does.
#
# It works because nothing under home/joshr/ writes the name "joshr" into a
# path. The home directory, the Firefox profile directory and the private
# desktop-entry IDs are all built from `config.home.username` or
# `config.home.homeDirectory` — so setting the name below is what redirects
# all of them. See the comment on `home.username` in home/joshr/home.nix.
#
# The system side of the account — groups, shell, password — is
# modules/nixos/users.nix. joshr is still the primary user there: the login
# screen, the boot menu and the OpenRGB resume service all follow
# `local.desktop.primaryUser`, which is joshr.
{
  # Overrides the `lib.mkDefault "joshr"` in home/joshr/home.nix and
  # home/joshr/server.nix. `home.homeDirectory` is derived from it on both
  # sides, so /home/sabom follows without being written down anywhere.
  home.username = "sabom";

  # Not overridden, and worth knowing: git commits from this account carry
  # joshr's identity — home/common/git.nix on the desktop hosts, stated again
  # in home/joshr/server.nix on the server. To give this account its own, take
  # `lib` in the arguments above and force it past that definition; both are
  # ordinary priority, so a plain assignment would be a conflict:
  #
  #   programs.git.settings.user = lib.mkForce {
  #     name = "Michael Sabo";
  #     email = "michael@example.com";
  #   };
}
