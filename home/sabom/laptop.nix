{ ... }:

# sabom's home profile on the laptop, Plasma session.
#
# joshr's entrypoint for this host, verbatim — single-display panels and the
# powerdevil lid handling included. ./home.nix names the account.
{
  imports = [
    ./home.nix
    ../joshr/laptop.nix
  ];
}
