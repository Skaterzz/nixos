{ ... }:

# joshr's home profile on the laptop, niri session.
#
# niri's per-monitor behaviour is driven by the outputs actually present
# rather than by hardcoded screen indices, so unlike the Plasma variant there
# is nothing single-display to switch off here.
#
# The display layout lives in ./displays/laptop.nix.
{
  imports = [
    ./home.nix
    ./niri
    ./displays/laptop.nix
    ./desktop-apps.nix
    ./office.nix
  ];

  # No OpenRGB tray applet at login here. The option defaults to true for the
  # desk, which has RGB hardware worth driving; on the laptop the applet has
  # nothing to talk to but still costs a tray icon, a Qt process and a failed
  # profile load every session.
  #
  # This only stops the *applet* autostarting. `openrgb` is still installed
  # (../home.nix) and the daemon is still enabled by modules/nixos/gaming.nix,
  # so launching it by hand on a docked keyboard or mouse still works.
}
