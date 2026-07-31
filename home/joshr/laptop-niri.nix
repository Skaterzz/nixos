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

  # local.niri.outputs is deliberately left empty: a laptop's external
  # displays change, and a hardcoded layout would mis-position whatever is
  # plugged in next. niri auto-detects instead.
  #
  # To pin the built-in panel — e.g. to force a refresh rate the preferred
  # mode doesn't pick — get the connector from `niri msg outputs` and add it
  # the way hosts/../gamestation-niri.nix does:
  #
  #   local.niri.outputs = [
  #     { name = "eDP-1"; mode = "2880x1800@120.000"; scale = 1.5; }
  #   ];
}
