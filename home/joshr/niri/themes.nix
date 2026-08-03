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
# Optional:
#
#   ansi      the 16 terminal colours, for kitty. Eight hues plus a bright
#             variant of each: black/red/green/yellow/blue/magenta/cyan/white
#             and brightBlack/brightRed/… Omit it and theming.nix derives one
#             from the roles above, which is legible but flat — the roles have
#             no blue, magenta or cyan in them, so a derived palette has to
#             reuse the accent for all three and syntax highlighting loses
#             most of its distinctions. Themes with a published terminal
#             palette use it verbatim; the rest are hand-picked.
#
# Adding a theme is adding one attrset here. Nothing else needs touching.
{
  # Applied on a fresh install, and the palette SDDM is built with unless
  # overridden. See MANUAL.md for how the login screen follows runtime
  # switches.
  default = "nord";

  themes = {
    # ---- house -----------------------------------------------------------

    # joshrandall.net's colours: dark neutral grey and a pastel green.
    #
    # The green is deliberately soft rather than the phosphor green `matrix`
    # wears. accent is used as a *background* in several places — waybar's
    # active workspace, wofi's selected row, kitty's selection — with `bg` as
    # the text on top of it, so a pastel reads as a calm highlight where a
    # saturated green reads as a highlighter pen.
    #
    # The greys carry no hue on purpose: with one pastel accent, any tint in
    # the background turns the whole session slightly sick-looking. So the
    # bar, the panels and the terminal chrome stay neutral, and the only
    # colours on screen are the green, the warning amber and the error rose
    # — of which only the green is there to be looked at.
    joshrandall-net = {
      description = "joshrandall.net — dark grey and pastel green";
      bg = "#1b1d1c";
      bgAlt = "#262a28";
      bgUrgent = "#33201f";
      fg = "#e4e8e5";
      fgDim = "#8b938e";
      accent = "#a8e6a3";
      accentDim = "#4a6f4a";
      warn = "#e8d9a0";
      err = "#e8a0a0";
      border = "#4a6f4a";
      # The whole ANSI set is pastel, not just the green — a saturated red or
      # blue beside a pastel accent looks like a different theme leaking in.
      # Each hue is a light tint at roughly the accent's lightness, which
      # keeps them distinguishable from each other and legible on the grey.
      ansi = {
        black = "#1b1d1c";       brightBlack = "#4a514d";
        red = "#e8a0a0";         brightRed = "#f2bcbc";
        green = "#a8e6a3";       brightGreen = "#c3f0bf";
        yellow = "#e8d9a0";      brightYellow = "#f2e8bf";
        blue = "#a0c8e8";        brightBlue = "#bfdcf2";
        magenta = "#d4b8e8";     brightMagenta = "#e4d1f2";
        cyan = "#a0e6dc";        brightCyan = "#bff0ea";
        white = "#e4e8e5";       brightWhite = "#f4f7f5";
      };
    };

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
      # Green-forward, but the other six hues stay genuinely distinct — a
      # terminal where magenta is also green makes diffs and syntax
      # highlighting unreadable. The chrome carries the theme; these just
      # have to be legible on near-black.
      ansi = {
        black = "#0a0e0a";       brightBlack = "#2a3a2a";
        red = "#ff5555";         brightRed = "#ff7b7b";
        green = "#39ff14";       brightGreen = "#7dff5e";
        yellow = "#d4e157";      brightYellow = "#e6f58a";
        blue = "#22d3ee";        brightBlue = "#67e8f9";
        magenta = "#b57edc";     brightMagenta = "#cfa3ec";
        cyan = "#2ee6a8";        brightCyan = "#6ff0c6";
        white = "#c8f5c8";       brightWhite = "#eaffea";
      };
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
      ansi = {
        black = "#0b0f0c";       brightBlack = "#2b3a2f";
        red = "#e06c75";         brightRed = "#ef8f97";
        green = "#4ade80";       brightGreen = "#86efac";
        yellow = "#e3c07b";      brightYellow = "#f0d5a0";
        blue = "#56b6c2";        brightBlue = "#7fd1db";
        magenta = "#b57edc";     brightMagenta = "#cfa3ec";
        cyan = "#4fd6a8";        brightCyan = "#83e6c6";
        white = "#cfe8d4";       brightWhite = "#eaf6ed";
      };
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
      ansi = {
        black = "#080d0d";       brightBlack = "#24393a";
        red = "#ef6b73";         brightRed = "#f79098";
        green = "#2ee6a8";       brightGreen = "#6ff0c6";
        yellow = "#ecd08a";      brightYellow = "#f5e2b4";
        blue = "#4dc4e0";        brightBlue = "#82daee";
        magenta = "#b18ae0";     brightMagenta = "#cbaeed";
        cyan = "#34d3c4";        brightCyan = "#74e5da";
        white = "#c4f0e4";       brightWhite = "#e6faf4";
      };
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
      # No hue in the terminal either, which is the point of the theme — but
      # it costs something real: a red/green diff can only be told apart by
      # lightness. So the eight hues are spread across the grey ramp rather
      # than collapsed onto one value, darkest for red through lightest for
      # white. Distinguishable, just not at a glance.
      ansi = {
        black = "#000000";       brightBlack = "#4a4a4a";
        red = "#6e6e6e";         brightRed = "#9a9a9a";
        green = "#8a8a8a";       brightGreen = "#b0b0b0";
        yellow = "#a0a0a0";      brightYellow = "#c8c8c8";
        blue = "#5c5c5c";        brightBlue = "#8a8a8a";
        magenta = "#787878";     brightMagenta = "#a4a4a4";
        cyan = "#949494";        brightCyan = "#bcbcbc";
        white = "#f2f2f2";       brightWhite = "#ffffff";
      };
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
      # The same ramp inverted: dark text on a light background, so the
      # ordering runs darkest-for-emphasis instead.
      ansi = {
        black = "#0d0d0d";       brightBlack = "#4a4a4a";
        red = "#8a8a8a";         brightRed = "#6e6e6e";
        green = "#6b6b6b";       brightGreen = "#4f4f4f";
        yellow = "#5c5c5c";      brightYellow = "#404040";
        blue = "#9a9a9a";        brightBlue = "#7a7a7a";
        magenta = "#808080";     brightMagenta = "#626262";
        cyan = "#737373";        brightCyan = "#555555";
        white = "#d4d4d4";       brightWhite = "#ebebeb";
      };
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
      ansi = {
        black = "#0d0000";       brightBlack = "#3a1a1a";
        red = "#ff2b2b";         brightRed = "#ff6b6b";
        green = "#6bbf59";       brightGreen = "#8fd97f";
        yellow = "#f5a623";      brightYellow = "#ffc457";
        blue = "#4a90d9";        brightBlue = "#74aee6";
        magenta = "#c678dd";     brightMagenta = "#dda0ec";
        cyan = "#56b6c2";        brightCyan = "#7fd1db";
        white = "#f0d5d5";       brightWhite = "#fdf0f0";
      };
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
      ansi = {
        black = "#14090b";       brightBlack = "#3d2429";
        red = "#e0384f";         brightRed = "#ff5d6c";
        green = "#7fb069";       brightGreen = "#9fc98c";
        yellow = "#e0a458";      brightYellow = "#edc186";
        blue = "#5a9ec7";        brightBlue = "#84badb";
        magenta = "#b87eb0";     brightMagenta = "#d0a3ca";
        cyan = "#5fb3b3";        brightCyan = "#88cccc";
        white = "#eddcdf";       brightWhite = "#fbf2f4";
      };
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
      # Catppuccin's published terminal palette. Surface1/Surface2 for the
      # blacks, Subtext1/Subtext0 for the whites, and no separate bright
      # variants for the six hues — that's upstream's choice, not an omission.
      ansi = {
        black = "#45475a";       brightBlack = "#585b70";
        red = "#f38ba8";         brightRed = "#f38ba8";
        green = "#a6e3a1";       brightGreen = "#a6e3a1";
        yellow = "#f9e2af";      brightYellow = "#f9e2af";
        blue = "#89b4fa";        brightBlue = "#89b4fa";
        magenta = "#f5c2e7";     brightMagenta = "#f5c2e7";
        cyan = "#94e2d5";        brightCyan = "#94e2d5";
        white = "#bac2de";       brightWhite = "#a6adc8";
      };
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
      ansi = {
        black = "#494d64";       brightBlack = "#5b6078";
        red = "#ed8796";         brightRed = "#ed8796";
        green = "#a6da95";       brightGreen = "#a6da95";
        yellow = "#eed49f";      brightYellow = "#eed49f";
        blue = "#8aadf4";        brightBlue = "#8aadf4";
        magenta = "#f5bde6";     brightMagenta = "#f5bde6";
        cyan = "#8bd5ca";        brightCyan = "#8bd5ca";
        white = "#b8c0e0";       brightWhite = "#a5adcb";
      };
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
      ansi = {
        black = "#51576d";       brightBlack = "#626880";
        red = "#e78284";         brightRed = "#e78284";
        green = "#a6d189";       brightGreen = "#a6d189";
        yellow = "#e5c890";      brightYellow = "#e5c890";
        blue = "#8caaee";        brightBlue = "#8caaee";
        magenta = "#f4b8e4";     brightMagenta = "#f4b8e4";
        cyan = "#81c8be";        brightCyan = "#81c8be";
        white = "#b5bfe2";       brightWhite = "#a5adce";
      };
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
      # Rosé Pine's own mapping, which is idiosyncratic on purpose: "green"
      # is Pine (a teal-blue) and "cyan" is Rose. Kept as published — the
      # palette is designed as a whole and substituting a literal green
      # breaks it.
      ansi = {
        black = "#26233a";       brightBlack = "#6e6a86";
        red = "#eb6f92";         brightRed = "#eb6f92";
        green = "#31748f";       brightGreen = "#31748f";
        yellow = "#f6c177";      brightYellow = "#f6c177";
        blue = "#9ccfd8";        brightBlue = "#9ccfd8";
        magenta = "#c4a7e7";     brightMagenta = "#c4a7e7";
        cyan = "#ebbcba";        brightCyan = "#ebbcba";
        white = "#e0def4";       brightWhite = "#e0def4";
      };
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
      ansi = {
        black = "#393552";       brightBlack = "#6e6a86";
        red = "#eb6f92";         brightRed = "#eb6f92";
        green = "#3e8fb0";       brightGreen = "#3e8fb0";
        yellow = "#f6c177";      brightYellow = "#f6c177";
        blue = "#9ccfd8";        brightBlue = "#9ccfd8";
        magenta = "#c4a7e7";     brightMagenta = "#c4a7e7";
        cyan = "#ea9a97";        brightCyan = "#ea9a97";
        white = "#e0def4";       brightWhite = "#e0def4";
      };
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
      ansi = {
        black = "#3b4252";       brightBlack = "#4c566a";
        red = "#bf616a";         brightRed = "#bf616a";
        green = "#a3be8c";       brightGreen = "#a3be8c";
        yellow = "#ebcb8b";      brightYellow = "#ebcb8b";
        blue = "#81a1c1";        brightBlue = "#81a1c1";
        magenta = "#b48ead";     brightMagenta = "#b48ead";
        cyan = "#88c0d0";        brightCyan = "#8fbcbb";
        white = "#e5e9f0";       brightWhite = "#eceff4";
      };
    };

    # Gruvbox ships three background contrasts — medium, hard and soft — over
    # one set of hues, plus a light mode. All four are transcribed from
    # morhetz/gruvbox's own palette: dark0_hard #1d2021, dark0 #282828,
    # dark0_soft #32302f and light0 #fbf1c7 for the backgrounds, light1
    # #ebdbb2 for text on the dark ones, gray #928374 for dimmed text, and
    # bright_orange #fe8019 as the accent on all three dark variants.
    gruvbox = {
      description = "Gruvbox dark (medium contrast)";
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
      # Gruvbox is one of the few that genuinely uses its bright variants —
      # the neutral/bright split is core to the palette.
      ansi = {
        black = "#282828";       brightBlack = "#928374";
        red = "#cc241d";         brightRed = "#fb4934";
        green = "#98971a";       brightGreen = "#b8bb26";
        yellow = "#d79921";      brightYellow = "#fabd2f";
        blue = "#458588";        brightBlue = "#83a598";
        magenta = "#b16286";     brightMagenta = "#d3869b";
        cyan = "#689d6a";        brightCyan = "#8ec07c";
        white = "#a89984";       brightWhite = "#ebdbb2";
      };
    };

    # dark0_hard. Same hues, a darker canvas — more contrast under the text
    # and a blacker surround for a bright room or an OLED panel. bgAlt stays
    # at dark1 rather than dropping to dark0: raised surfaces have to stay
    # visibly raised, and #1d2021 against #282828 is a step you can barely
    # see.
    gruvbox-hard = {
      description = "Gruvbox dark (hard contrast)";
      bg = "#1d2021";
      bgAlt = "#3c3836";
      bgUrgent = "#401f1d";
      fg = "#ebdbb2";
      fgDim = "#928374";
      accent = "#fe8019";
      accentDim = "#8f4a12";
      warn = "#fabd2f";
      err = "#fb4934";
      border = "#8f4a12";
      ansi = {
        black = "#1d2021";       brightBlack = "#928374";
        red = "#cc241d";         brightRed = "#fb4934";
        green = "#98971a";       brightGreen = "#b8bb26";
        yellow = "#d79921";      brightYellow = "#fabd2f";
        blue = "#458588";        brightBlue = "#83a598";
        magenta = "#b16286";     brightMagenta = "#d3869b";
        cyan = "#689d6a";        brightCyan = "#8ec07c";
        white = "#a89984";       brightWhite = "#ebdbb2";
      };
    };

    # dark0_soft, the other direction: a lifted, warmer background for a dim
    # room. Here bgAlt has to go *up* to dark2 for the same reason hard's
    # stays put — dark1 #3c3836 is only a few points off #32302f and raised
    # surfaces would disappear into the background.
    gruvbox-soft = {
      description = "Gruvbox dark (soft contrast)";
      bg = "#32302f";
      bgAlt = "#504945";
      bgUrgent = "#52322e";
      fg = "#ebdbb2";
      fgDim = "#928374";
      accent = "#fe8019";
      accentDim = "#8f4a12";
      warn = "#fabd2f";
      err = "#fb4934";
      border = "#8f4a12";
      ansi = {
        black = "#32302f";       brightBlack = "#928374";
        red = "#cc241d";         brightRed = "#fb4934";
        green = "#98971a";       brightGreen = "#b8bb26";
        yellow = "#d79921";      brightYellow = "#fabd2f";
        blue = "#458588";        brightBlue = "#83a598";
        magenta = "#b16286";     brightMagenta = "#d3869b";
        cyan = "#689d6a";        brightCyan = "#8ec07c";
        white = "#a89984";       brightWhite = "#ebdbb2";
      };
    };

    # Gruvbox light, kept here with its siblings rather than in the light
    # section below — same reason mono-light sits with mono.
    #
    # Upstream doesn't just invert the dark scheme: light mode swaps the
    # bright hues for the faded ones, because on paper a colour reads as
    # emphasised by getting darker. So the accent is faded_orange #af3a03
    # rather than bright_orange, which is also the only version of it that
    # can carry #fbf1c7 text when the accent is used as a background.
    gruvbox-light = {
      description = "Gruvbox light";
      bg = "#fbf1c7";
      bgAlt = "#ebdbb2";
      bgUrgent = "#f0d3c4";
      fg = "#3c3836";
      fgDim = "#7c6f64";
      accent = "#af3a03";
      accentDim = "#d5c4a1";
      warn = "#b57614";
      err = "#9d0006";
      border = "#d5c4a1";
      # Gruvbox's published light terminal palette: neutral_* in the normal
      # slots, faded_* in the bright ones — darker, not lighter, for the same
      # reason the accent is.
      ansi = {
        black = "#fbf1c7";       brightBlack = "#928374";
        red = "#cc241d";         brightRed = "#9d0006";
        green = "#98971a";       brightGreen = "#79740e";
        yellow = "#d79921";      brightYellow = "#b57614";
        blue = "#458588";        brightBlue = "#076678";
        magenta = "#b16286";     brightMagenta = "#8f3f71";
        cyan = "#689d6a";        brightCyan = "#427b58";
        white = "#7c6f64";       brightWhite = "#3c3836";
      };
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
      ansi = {
        black = "#21222c";       brightBlack = "#6272a4";
        red = "#ff5555";         brightRed = "#ff6e6e";
        green = "#50fa7b";       brightGreen = "#69ff94";
        yellow = "#f1fa8c";      brightYellow = "#ffffa5";
        blue = "#bd93f9";        brightBlue = "#d6acff";
        magenta = "#ff79c6";     brightMagenta = "#ff92df";
        cyan = "#8be9fd";        brightCyan = "#a4ffff";
        white = "#f8f8f2";       brightWhite = "#ffffff";
      };
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
      ansi = {
        black = "#15161e";       brightBlack = "#414868";
        red = "#f7768e";         brightRed = "#f7768e";
        green = "#9ece6a";       brightGreen = "#9ece6a";
        yellow = "#e0af68";      brightYellow = "#e0af68";
        blue = "#7aa2f7";        brightBlue = "#7aa2f7";
        magenta = "#bb9af7";     brightMagenta = "#bb9af7";
        cyan = "#7dcfff";        brightCyan = "#7dcfff";
        white = "#a9b1d6";       brightWhite = "#c0caf5";
      };
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
      ansi = {
        black = "#414b50";       brightBlack = "#4b565c";
        red = "#e67e80";         brightRed = "#e67e80";
        green = "#a7c080";       brightGreen = "#a7c080";
        yellow = "#dbbc7f";      brightYellow = "#dbbc7f";
        blue = "#7fbbb3";        brightBlue = "#7fbbb3";
        magenta = "#d699b6";     brightMagenta = "#d699b6";
        cyan = "#83c092";        brightCyan = "#83c092";
        white = "#d3c6aa";       brightWhite = "#d3c6aa";
      };
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
      ansi = {
        black = "#16161d";       brightBlack = "#727169";
        red = "#c34043";         brightRed = "#e82424";
        green = "#76946a";       brightGreen = "#98bb6c";
        yellow = "#c0a36e";      brightYellow = "#e6c384";
        blue = "#7e9cd8";        brightBlue = "#7fb4ca";
        magenta = "#957fb8";     brightMagenta = "#938aa9";
        cyan = "#6a9589";        brightCyan = "#7aa89f";
        white = "#c8c093";       brightWhite = "#dcd7ba";
      };
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
      # Solarized's famous quirk: the bright slots aren't brighter versions of
      # the hues, they're the base greys (base01–base3). Ethan Schoonover
      # designed it that way so the 16 slots carry the full tonal ramp.
      # Transcribed as specified.
      ansi = {
        black = "#073642";       brightBlack = "#002b36";
        red = "#dc322f";         brightRed = "#cb4b16";
        green = "#859900";       brightGreen = "#586e75";
        yellow = "#b58900";      brightYellow = "#657b83";
        blue = "#268bd2";        brightBlue = "#839496";
        magenta = "#d33682";     brightMagenta = "#6c71c4";
        cyan = "#2aa198";        brightCyan = "#93a1a1";
        white = "#eee8d5";       brightWhite = "#fdf6e3";
      };
    };

    # ---- originals -------------------------------------------------------
    # Not transcriptions of anything — built here, to the same rules the
    # borrowed palettes are judged by: the accent has to survive being used
    # as a background with `bg` written on top of it, `err` has to be
    # tellable from the accent at a glance (a red battery beside an accented
    # clock), and the sixteen terminal colours have to keep six distinct
    # hues so a diff or a syntax highlighter still reads.

    # Retro-neon: the accent is a magenta rather than the usual blue or
    # green, over a violet-black that isn't quite neutral. The ANSI set keeps
    # the era's other two signature colours — electric cyan and a lime
    # yellow — so a terminal looks of a piece with the chrome.
    synthwave = {
      description = "Neon magenta over midnight violet";
      bg = "#1a1030";
      bgAlt = "#251a45";
      bgUrgent = "#45152e";
      fg = "#f0e6ff";
      fgDim = "#8b7bb8";
      accent = "#ff2f92";
      accentDim = "#8a1350";
      warn = "#ffd166";
      err = "#ff4d6d";
      border = "#8a1350";
      # err (#ff4d6d) sits close to the accent in hue, which is a real risk
      # in a pink-forward theme — so it is held distinctly redder and lighter
      # than accent, and never appears next to it on the same widget.
      ansi = {
        black = "#1a1030";       brightBlack = "#4a3a75";
        red = "#ff4d6d";         brightRed = "#ff7d95";
        green = "#4ee9a1";       brightGreen = "#7ff5c0";
        yellow = "#f9f871";      brightYellow = "#fdfca8";
        blue = "#5b7cfa";        brightBlue = "#8aa0ff";
        magenta = "#ff2f92";     brightMagenta = "#ff6fb5";
        cyan = "#2de2e6";        brightCyan = "#7af4f7";
        white = "#e6dcff";       brightWhite = "#ffffff";
      };
    };

    # Warm without being brown. Gruvbox's orange sits on a warm grey and the
    # whole palette leans sepia; this one puts a golden amber on a properly
    # neutral near-black, so the accent is the only warm thing on screen and
    # reads as a lit coal rather than as a tint over everything.
    ember = {
      description = "Amber embers on cold charcoal";
      bg = "#131313";
      bgAlt = "#1f1e1d";
      bgUrgent = "#331411";
      fg = "#ece4d9";
      fgDim = "#8a8078";
      accent = "#ffb03a";
      accentDim = "#8a4e0d";
      warn = "#ffd166";
      err = "#ff5c47";
      border = "#8a4e0d";
      # A warm accent means warn and err both crowd it. warn is pulled up
      # into yellow and err down into red, far enough either side of the
      # accent's gold that battery-low and battery-critical never read as the
      # same state.
      ansi = {
        black = "#131313";       brightBlack = "#4a4340";
        red = "#ef4f3a";         brightRed = "#ff7a68";
        green = "#9bbf6a";       brightGreen = "#b9d68f";
        yellow = "#ffb03a";      brightYellow = "#ffca77";
        blue = "#56a3c9";        brightBlue = "#86c2de";
        magenta = "#c38fd6";     brightMagenta = "#d8b3e6";
        cyan = "#57bfae";        brightCyan = "#88d5c8";
        white = "#ece4d9";       brightWhite = "#fbf6f0";
      };
    };

    # Deep water: a blue-black background with one cold, bright cyan on it.
    # The nearest neighbours here are mint (green-teal on near-black) and
    # rose-pine-moon (teal on plum) — this one is bluer than either, and the
    # background carries enough blue to be visibly not-black beside them.
    abyss = {
      description = "Bioluminescent cyan in deep water";
      bg = "#06121a";
      bgAlt = "#0d1f2b";
      bgUrgent = "#2c1220";
      fg = "#cfe9f0";
      fgDim = "#5c7f8c";
      accent = "#22d3ee";
      accentDim = "#0e6a80";
      warn = "#ffc857";
      err = "#ff6b81";
      border = "#0e6a80";
      ansi = {
        black = "#06121a";       brightBlack = "#26414d";
        red = "#ff6b81";         brightRed = "#ff97a7";
        green = "#35d6a5";       brightGreen = "#6fe8c4";
        yellow = "#ffc857";      brightYellow = "#ffdb8c";
        blue = "#4aa8ff";        brightBlue = "#86c6ff";
        magenta = "#a78bfa";     brightMagenta = "#c4b0fd";
        cyan = "#22d3ee";        brightCyan = "#67e8f9";
        white = "#cfe9f0";       brightWhite = "#eaf7fb";
      };
    };

    # The quiet counterpart to synthwave: the same corner of the wheel at a
    # tenth of the volume, pastel rose on an ink-plum background. Two pinks
    # in one file is deliberate — the file already carries five greens and
    # five purples, and neon and pastel are not interchangeable at 2am.
    sakura = {
      description = "Pastel rose on ink plum";
      bg = "#1a141c";
      bgAlt = "#251d29";
      bgUrgent = "#3d1a2a";
      fg = "#f2e4ee";
      fgDim = "#8d7b8d";
      accent = "#f0a8c8";
      accentDim = "#7d4f68";
      warn = "#f0cf9a";
      err = "#f07a8f";
      border = "#7d4f68";
      ansi = {
        black = "#1a141c";       brightBlack = "#4a3b4a";
        red = "#f07a8f";         brightRed = "#f7a3b1";
        green = "#a8d9a0";       brightGreen = "#c4e8be";
        yellow = "#f0cf9a";      brightYellow = "#f7e2c1";
        blue = "#97b8e8";        brightBlue = "#b8d0f2";
        magenta = "#f0a8c8";     brightMagenta = "#f7c6dc";
        cyan = "#96dcd2";        brightCyan = "#b9ebe4";
        white = "#f2e4ee";       brightWhite = "#fdf5fa";
      };
    };

    # ---- light -----------------------------------------------------------
    # The light palettes that don't belong to a family above; `mono-light`
    # and `gruvbox-light` live beside their dark siblings instead.
    #
    # Light themes need two things doing differently. The accent is a *dark*
    # colour, not a bright one, because it still has to take `bg` as text on
    # top of it — a pastel accent on a pale background leaves the active
    # workspace unreadable. And the ANSI bright slots run darker than the
    # normal ones rather than lighter, since on a light background emphasis
    # comes from going down towards the ink, not up towards the paper. (Only
    # where a palette distinguishes the two at all: Rosé Pine Dawn publishes
    # one value per hue and both slots take it, as upstream intends.)

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
      ansi = {
        black = "#f2e9e1";       brightBlack = "#9893a5";
        red = "#b4637a";         brightRed = "#b4637a";
        green = "#286983";       brightGreen = "#286983";
        yellow = "#ea9d34";      brightYellow = "#ea9d34";
        blue = "#56949f";        brightBlue = "#56949f";
        magenta = "#907aa9";     brightMagenta = "#907aa9";
        cyan = "#d7827e";        brightCyan = "#d7827e";
        white = "#575279";       brightWhite = "#575279";
      };
    };

    # Warm paper rather than white: an unbleached off-white with a sienna
    # accent, for a bright room. Rosé Pine Dawn is the cool light option and
    # Gruvbox light is the yellow one; this sits between them, warm without
    # gruvbox's cream.
    #
    # accentDim is a tan, not a dark sienna. On a dark theme accentDim is a
    # dimmer version of the accent; on a light one it is a *lighter* one,
    # because it draws inactive borders and scrollbar thumbs — things that
    # have to recede into the page, and a dark border recedes from nothing.
    sandstone = {
      description = "Warm paper and sienna (light)";
      bg = "#f6f1e7";
      bgAlt = "#ede5d6";
      bgUrgent = "#f2d9cc";
      fg = "#3b3730";
      fgDim = "#7d7466";
      accent = "#b0562a";
      accentDim = "#d3c3a8";
      warn = "#a8730f";
      err = "#a83232";
      border = "#d3c3a8";
      ansi = {
        black = "#e6dcc9";       brightBlack = "#7d7466";
        red = "#a83232";         brightRed = "#8a2020";
        green = "#5d7a2e";       brightGreen = "#47601f";
        yellow = "#a8730f";      brightYellow = "#8a5c07";
        blue = "#2f6f8f";        brightBlue = "#1e5570";
        magenta = "#8a4a72";     brightMagenta = "#6f375a";
        cyan = "#2f7d70";        brightCyan = "#1e6357";
        white = "#3b3730";       brightWhite = "#26231e";
      };
    };
  };
}
