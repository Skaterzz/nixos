{ ... }:

# sabom's home profile on the laptop, niri session.
#
# joshr's entrypoint for this host, verbatim, which is where
# `local.niri.shell = "noctalia"` is set — so this account gets the same shell,
# lock screen and theme pipeline joshr's session runs, with its own state under
# its own home. ./home.nix names the account.
{
  imports = [
    ./home.nix
    ../joshr/laptop-niri.nix
  ];
}
