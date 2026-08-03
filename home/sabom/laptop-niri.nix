{ ... }:

# raiden's home profile on the laptop, niri session.
#
# joshr's entrypoint for this host, verbatim. ./home.nix names the account.
{
  imports = [
    ./home.nix
    ../joshr/laptop-niri.nix
  ];
}
