{ ... }:

# joshr's home profile on the laptop, niri session.
#
# niri's per-monitor behaviour is driven by the outputs actually present
# rather than by hardcoded screen indices, so unlike the Plasma variant there
# is nothing single-display to switch off here — this is the same as the desk
# profile today. It exists as its own file so laptop-only tweaks have an
# obvious home.
{
  imports = [
    ./home.nix
    ./niri
  ];
}
