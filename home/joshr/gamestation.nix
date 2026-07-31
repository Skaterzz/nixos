{ ... }:

# joshr's home profile on the desk, Plasma session: multi-monitor, so the
# second-screen status bar is wanted.
{
  imports = [
    ./home.nix
    ./plasma.nix
  ];

  local.plasma.secondaryMonitorPanel = true;
}
