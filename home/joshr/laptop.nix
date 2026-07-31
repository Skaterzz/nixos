{ ... }:

# joshr's home profile on the laptop, Plasma session. Identical to the desk
# apart from the panels: only the built-in display, so the screen-1 status bar
# is left off (`local.plasma.secondaryMonitorPanel` defaults to false).
#
# The dock and the screen-0 status bar are still both present, since those
# live on the primary display either way.
{
  imports = [
    ./home.nix
    ./plasma.nix
  ];
}
