{ ... }:

# joshr's home profile on the desk: multi-monitor, so the second-screen
# status bar is wanted.
{
  imports = [ ./home.nix ];

  local.plasma.secondaryMonitorPanel = true;
}
