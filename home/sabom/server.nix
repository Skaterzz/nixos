{ ... }:

# sabom's home profile on the server.
#
# joshr's entrypoint for this host, verbatim — which on this machine is the
# shared shell and nothing else, deliberately not built on the desktop base.
# ./home.nix names the account.
{
  imports = [
    ./home.nix
    ../joshr/server.nix
  ];
}
