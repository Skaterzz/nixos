{ ... }:

# Display layout for the laptop.
#
# Deliberately empty: a laptop's external displays change, and a hardcoded
# layout would mis-position whatever gets plugged in next. niri auto-detects
# instead, which is the right default here.
#
# To pin the built-in panel — e.g. to force a refresh rate its preferred mode
# doesn't pick — get the connector from `niri msg outputs` and fill this in
# the same shape as ./gamestation.nix:
#
#   local.niri.outputs = [
#     {
#       name = "eDP-1";
#       mode = "2880x1800@120.000";
#       scale = 2;
#     }
#   ];
#
# `scale` only takes integers here: fractional scaling is off by choice, and
# a declared output is written out with an explicit `scale 1` when the field
# is omitted so niri's DPI guess can't reintroduce one. On a dense panel that
# means choosing between 1 (everything small, everything sharp) and 2
# (everything large), with font sizes doing the rest.
{
  local.niri.outputs = [ ];
}
