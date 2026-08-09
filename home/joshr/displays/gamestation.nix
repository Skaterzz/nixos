{ ... }:

# Display layout for the desk.
#
# This is the file to edit when a monitor changes — nothing else in here
# depends on it. Imported by home/joshr/gamestation-niri.nix.
#
# Get connector names and the modes each display actually reports with:
#
#     niri msg outputs
#
# The refresh rates are stated explicitly because a display's preferred mode
# is frequently not its fastest; without them you can silently end up at
# 60Hz. The string has to match a mode the display reports, or niri falls
# back to the preferred mode and only logs a warning.
#
# Positions are in *logical* pixels, so a scaled output occupies
# width / scale. DP-2 starts at x=2560 because DP-3 is unscaled — if DP-3
# ever gets a scale, that number becomes 2560 / scale.
{
  # Numbered workspaces (Mod+1..5) all live on the 1440p panel. Without this
  # niri creates each one on whichever output was focused at the time, so
  # they end up scattered across both displays.
  local.niri.workspaceOutput = "DP-3";

  local.niri.outputs = [
    {
      name = "DP-3";
      mode = "2560x1440@179.952";
      position = {
        x = 0;
        y = 0;
      };
      # niri has no "primary" display; this is the nearest equivalent — the
      # session starts focused here. To also pin workspaces to this output,
      # give them an `open-on-output` in the workspace declarations in
      # home/joshr/niri/niri.nix.
      focusAtStartup = true;
    }
    {
      name = "DP-2";
      mode = "1920x1080@100.000";
      # Top-aligned with DP-3 rather than centred against it. Set y = 180 to
      # centre the 1080p panel against the 1440p one instead.
      position = {
        x = 2560;
        y = 0;
      };
    }
  ];
}
