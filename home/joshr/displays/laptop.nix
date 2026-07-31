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
#       scale = 1.5;
#     }
#   ];
{
  local.niri.outputs = [ ];
}
