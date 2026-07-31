{ lib, ... }:

# Single source of truth for the desktop palette.
#
# Every themed surface — niri's focus ring, waybar, wofi, dunst, swaylock —
# reads its colours from here, so a theme is defined once and rendered into
# each tool's own config format by the modules that consume it.
#
# The brief was green and black. `matrix` is the default: near-black
# backgrounds with a bright phosphor green. The other two are the same shape
# with a different green, so switching themes doesn't rearrange anything —
# it only recolours.
{
  default = "matrix";

  themes = {
    # Bright phosphor green on near-black. High contrast, the default.
    matrix = {
      name = "matrix";
      description = "Phosphor green on black";

      bg = "#0a0e0a"; # window/bar background
      bgAlt = "#111811"; # raised surfaces (tray, menu rows)
      bgUrgent = "#2a0f0f";
      fg = "#c8f5c8"; # primary text
      fgDim = "#5c7a5c"; # secondary text, inactive
      accent = "#39ff14"; # the green
      accentDim = "#1f8b0d"; # inactive/unfocused variant
      warn = "#f5d76e";
      err = "#ff5555";
      border = "#1f8b0d";
    };

    # Deeper, softer green. Easier on the eyes for long sessions.
    forest = {
      name = "forest";
      description = "Deep forest green";

      bg = "#0b0f0c";
      bgAlt = "#131a15";
      bgUrgent = "#2a0f0f";
      fg = "#cfe8d4";
      fgDim = "#5f7a66";
      accent = "#4ade80";
      accentDim = "#22683c";
      warn = "#e3c07b";
      err = "#e06c75";
      border = "#22683c";
    };

    # Cyan-leaning green, cooler cast.
    mint = {
      name = "mint";
      description = "Cool mint green";

      bg = "#080d0d";
      bgAlt = "#101a1a";
      bgUrgent = "#2a0f0f";
      fg = "#c4f0e4";
      fgDim = "#578079";
      accent = "#2ee6a8";
      accentDim = "#14806a";
      warn = "#ecd08a";
      err = "#ef6b73";
      border = "#14806a";
    };
  };
}
