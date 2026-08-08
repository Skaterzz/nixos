{ ... }:

# sabom's home profile on the desk, Plasma session.
#
# joshr's entrypoint for this host, verbatim — including the second-monitor
# status bar it switches on, since it's the same two displays. ./home.nix
# names the account; nothing else here differs.
{
  imports = [
    ./home.nix
    ../joshr/gamestation.nix
  ];
}
