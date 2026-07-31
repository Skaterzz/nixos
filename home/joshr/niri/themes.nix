{ lib, ... }:

# Single source of truth for the desktop palette.
#
# Every themed surface — niri's focus ring, waybar, wofi, dunst, swaylock and
# the SDDM login screen — reads its colours from here. A theme is defined once
# and rendered into each tool's own config format by theming.nix.
#
# Keys, all required:
#
#   bg        window / bar background
#   bgAlt     raised surfaces (input fields, menu rows, tray)
#   bgUrgent  background for critical notifications
#   fg        primary text
#   fgDim     secondary text, inactive items
#   accent    the theme colour: active workspace, focus ring, prompt
#   accentDim inactive/unfocused variant of the accent
#   warn      warning text (low battery, cleared password field)
#   err       errors, urgent windows, wrong password
#   border    window and panel borders — usually the same as accentDim
#
# Adding a theme is adding one attrset here. Nothing else needs touching.
{
  # Applied on a fresh install, and the palette SDDM is built with unless
  # overridden. See README for how the login screen follows runtime switches.
  default = "matrix";

  themes = {
    # ---- greens ----------------------------------------------------------

    matrix = {
      description = "Phosphor green on black";
      bg = "#0a0e0a";
      bgAlt = "#111811";
      bgUrgent = "#2a0f0f";
      fg = "#c8f5c8";
      fgDim = "#5c7a5c";
      accent = "#39ff14";
      accentDim = "#1f8b0d";
      warn = "#f5d76e";
      err = "#ff5555";
      border = "#1f8b0d";
    };

    forest = {
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

    mint = {
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

    # ---- monochrome ------------------------------------------------------

    # No hue anywhere. The accent is plain white, so emphasis comes from
    # contrast rather than colour — the active workspace and focus ring go
    # white-on-black, and the usual green/amber/red for battery and errors
    # become greys. warn and err are kept fractionally lighter than fgDim so
    # a critical notification still reads as louder than a normal one without
    # introducing a colour.
    mono = {
      description = "Monochrome, black and white";
      bg = "#000000";
      bgAlt = "#141414";
      bgUrgent = "#2b2b2b";
      fg = "#f2f2f2";
      fgDim = "#8a8a8a";
      accent = "#ffffff";
      accentDim = "#4a4a4a";
      warn = "#c8c8c8";
      err = "#ffffff";
      border = "#4a4a4a";
    };

    # The inverse: black on white, for bright rooms.
    mono-light = {
      description = "Monochrome, white and black (light)";
      bg = "#fafafa";
      bgAlt = "#ebebeb";
      bgUrgent = "#d4d4d4";
      fg = "#0d0d0d";
      fgDim = "#6b6b6b";
      accent = "#000000";
      accentDim = "#b8b8b8";
      warn = "#4a4a4a";
      err = "#000000";
      border = "#b8b8b8";
    };

    # ---- reds ------------------------------------------------------------

    blackred = {
      description = "Black and red";
      bg = "#0d0000";
      bgAlt = "#1a0606";
      bgUrgent = "#3a0a0a";
      fg = "#f0d5d5";
      fgDim = "#7a5555";
      accent = "#ff2b2b";
      accentDim = "#8b0d0d";
      warn = "#f5a623";
      err = "#ff6b6b";
      border = "#8b0d0d";
    };

    crimson = {
      description = "Muted crimson on charcoal";
      bg = "#14090b";
      bgAlt = "#1f1114";
      bgUrgent = "#3a0f14";
      fg = "#eddcdf";
      fgDim = "#8a6a70";
      accent = "#e0384f";
      accentDim = "#7d1f2c";
      warn = "#e0a458";
      err = "#ff5d6c";
      border = "#7d1f2c";
    };

    # ---- catppuccin ------------------------------------------------------

    catppuccin-mocha = {
      description = "Catppuccin Mocha";
      bg = "#1e1e2e";
      bgAlt = "#313244";
      bgUrgent = "#45213a";
      fg = "#cdd6f4";
      fgDim = "#a6adc8";
      accent = "#cba6f7";
      accentDim = "#6c5a92";
      warn = "#f9e2af";
      err = "#f38ba8";
      border = "#6c5a92";
    };

    catppuccin-macchiato = {
      description = "Catppuccin Macchiato";
      bg = "#24273a";
      bgAlt = "#363a4f";
      bgUrgent = "#4a2436";
      fg = "#cad3f5";
      fgDim = "#a5adcb";
      accent = "#c6a0f6";
      accentDim = "#6b568f";
      warn = "#eed49f";
      err = "#ed8796";
      border = "#6b568f";
    };

    catppuccin-frappe = {
      description = "Catppuccin Frappé";
      bg = "#303446";
      bgAlt = "#414559";
      bgUrgent = "#4d2c3a";
      fg = "#c6d0f5";
      fgDim = "#a5adce";
      accent = "#ca9ee6";
      accentDim = "#6e567f";
      warn = "#e5c890";
      err = "#e78284";
      border = "#6e567f";
    };

    # ---- rosé pine -------------------------------------------------------

    rose-pine = {
      description = "Rosé Pine";
      bg = "#191724";
      bgAlt = "#1f1d2e";
      bgUrgent = "#3d1f2c";
      fg = "#e0def4";
      fgDim = "#6e6a86";
      accent = "#c4a7e7";
      accentDim = "#5d4d73";
      warn = "#f6c177";
      err = "#eb6f92";
      border = "#5d4d73";
    };

    rose-pine-moon = {
      description = "Rosé Pine Moon";
      bg = "#232136";
      bgAlt = "#2a273f";
      bgUrgent = "#42233a";
      fg = "#e0def4";
      fgDim = "#6e6a86";
      accent = "#9ccfd8";
      accentDim = "#3e6b73";
      warn = "#f6c177";
      err = "#eb6f92";
      border = "#3e6b73";
    };

    # ---- classics --------------------------------------------------------

    nord = {
      description = "Nord";
      bg = "#2e3440";
      bgAlt = "#3b4252";
      bgUrgent = "#4a2f34";
      fg = "#eceff4";
      fgDim = "#7b88a1";
      accent = "#88c0d0";
      accentDim = "#4c6b78";
      warn = "#ebcb8b";
      err = "#bf616a";
      border = "#4c6b78";
    };

    gruvbox = {
      description = "Gruvbox dark";
      bg = "#282828";
      bgAlt = "#3c3836";
      bgUrgent = "#4a2422";
      fg = "#ebdbb2";
      fgDim = "#928374";
      accent = "#fe8019";
      accentDim = "#8f4a12";
      warn = "#fabd2f";
      err = "#fb4934";
      border = "#8f4a12";
    };

    dracula = {
      description = "Dracula";
      bg = "#282a36";
      bgAlt = "#44475a";
      bgUrgent = "#4a2436";
      fg = "#f8f8f2";
      fgDim = "#6272a4";
      accent = "#bd93f9";
      accentDim = "#65508c";
      warn = "#f1fa8c";
      err = "#ff5555";
      border = "#65508c";
    };

    tokyo-night = {
      description = "Tokyo Night";
      bg = "#1a1b26";
      bgAlt = "#292e42";
      bgUrgent = "#3d2230";
      fg = "#c0caf5";
      fgDim = "#565f89";
      accent = "#7aa2f7";
      accentDim = "#3d5488";
      warn = "#e0af68";
      err = "#f7768e";
      border = "#3d5488";
    };

    everforest = {
      description = "Everforest dark";
      bg = "#2d353b";
      bgAlt = "#343f44";
      bgUrgent = "#4a2f2f";
      fg = "#d3c6aa";
      fgDim = "#859289";
      accent = "#a7c080";
      accentDim = "#586c44";
      warn = "#dbbc7f";
      err = "#e67e80";
      border = "#586c44";
    };

    kanagawa = {
      description = "Kanagawa";
      bg = "#1f1f28";
      bgAlt = "#2a2a37";
      bgUrgent = "#43242b";
      fg = "#dcd7ba";
      fgDim = "#727169";
      accent = "#7e9cd8";
      accentDim = "#435275";
      warn = "#e6c384";
      err = "#e82424";
      border = "#435275";
    };

    solarized = {
      description = "Solarized dark";
      bg = "#002b36";
      bgAlt = "#073642";
      bgUrgent = "#3d1a1a";
      fg = "#93a1a1";
      fgDim = "#586e75";
      accent = "#268bd2";
      accentDim = "#1a5a87";
      warn = "#b58900";
      err = "#dc322f";
      border = "#1a5a87";
    };

    # ---- light -----------------------------------------------------------
    # One light option, mostly so the switcher is visibly doing something.

    rose-pine-dawn = {
      description = "Rosé Pine Dawn (light)";
      bg = "#faf4ed";
      bgAlt = "#fffaf3";
      bgUrgent = "#f2e0e2";
      fg = "#575279";
      fgDim = "#9893a5";
      accent = "#907aa9";
      accentDim = "#c4b8d0";
      warn = "#ea9d34";
      err = "#b4637a";
      border = "#c4b8d0";
    };
  };
}
