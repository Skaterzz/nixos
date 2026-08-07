# Generated from Noctalia v5.0.0-beta.7's src/theme/builtin_palettes.cpp.
# These are deliberately separate from themes.nix: they are internal targets
# for mirroring a Noctalia builtin into non-Noctalia consumers, not additional
# custom palettes offered by the theme picker.
{
  selections = {
    "Ayu" = {
      dark = "noctalia-ayu-dark";
      light = "noctalia-ayu-light";
    };
    "Catppuccin" = {
      dark = "noctalia-catppuccin-dark";
      light = "noctalia-catppuccin-light";
    };
    "Dracula" = {
      dark = "noctalia-dracula-dark";
      light = "noctalia-dracula-light";
    };
    "Eldritch" = {
      dark = "noctalia-eldritch-dark";
      light = "noctalia-eldritch-light";
    };
    "Gruvbox" = {
      dark = "noctalia-gruvbox-dark";
      light = "noctalia-gruvbox-light";
    };
    "Kanagawa" = {
      dark = "noctalia-kanagawa-dark";
      light = "noctalia-kanagawa-light";
    };
    "Noctalia" = {
      dark = "noctalia-noctalia-dark";
      light = "noctalia-noctalia-light";
    };
    "Nord" = {
      dark = "noctalia-nord-dark";
      light = "noctalia-nord-light";
    };
    "Rosé Pine" = {
      dark = "noctalia-rose-pine-dark";
      light = "noctalia-rose-pine-light";
    };
    "Tokyo-Night" = {
      dark = "noctalia-tokyo-night-dark";
      light = "noctalia-tokyo-night-light";
    };
  };

  themes = {
    noctalia-ayu-dark = {
      description = "Noctalia builtin Ayu (dark)";
      bg = "#0B0E14";
      bgAlt = "#1e222a";
      bgUrgent = "#D95757";
      fg = "#D1D1C7";
      fgDim = "#8E959E";
      accent = "#E6B450";
      accentDim = "#AAD94C";
      warn = "#39BAE6";
      err = "#D95757";
      border = "#565B66";
      ansi = {
        black = "#171b24"; brightBlack = "#686868";
        red = "#ed8274"; brightRed = "#f28779";
        green = "#87d96c"; brightGreen = "#d5ff80";
        yellow = "#facc6e"; brightYellow = "#ffd173";
        blue = "#6dcbfa"; brightBlue = "#73d0ff";
        magenta = "#dabafa"; brightMagenta = "#dfbfff";
        cyan = "#90e1c6"; brightCyan = "#95e6cb";
        white = "#c7c7c7"; brightWhite = "#ffffff";
      };
    };
    noctalia-ayu-light = {
      description = "Noctalia builtin Ayu (light)";
      bg = "#F8F9FA";
      bgAlt = "#E4E6E9";
      bgUrgent = "#E65050";
      fg = "#42474C";
      fgDim = "#6E757C";
      accent = "#FF8F40";
      accentDim = "#86B300";
      warn = "#55B4D4";
      err = "#E65050";
      border = "#8A9199";
      ansi = {
        black = "#000000"; brightBlack = "#686868";
        red = "#ea6c6d"; brightRed = "#f07171";
        green = "#6cbf43"; brightGreen = "#86b300";
        yellow = "#eca944"; brightYellow = "#f2ae49";
        blue = "#3199e1"; brightBlue = "#399ee6";
        magenta = "#9e75c7"; brightMagenta = "#a37acc";
        cyan = "#46ba94"; brightCyan = "#4cbf99";
        white = "#bababa"; brightWhite = "#d1d1d1";
      };
    };
    noctalia-catppuccin-dark = {
      description = "Noctalia builtin Catppuccin (dark)";
      bg = "#1e1e2e";
      bgAlt = "#313244";
      bgUrgent = "#f38ba8";
      fg = "#cdd6f4";
      fgDim = "#a3b4eb";
      accent = "#cba6f7";
      accentDim = "#fab387";
      warn = "#94e2d5";
      err = "#f38ba8";
      border = "#4c4f69";
      ansi = {
        black = "#45475a"; brightBlack = "#585b70";
        red = "#f38ba8"; brightRed = "#f37799";
        green = "#a6e3a1"; brightGreen = "#89d88b";
        yellow = "#f9e2af"; brightYellow = "#ebd391";
        blue = "#89b4fa"; brightBlue = "#74a8fc";
        magenta = "#f5c2e7"; brightMagenta = "#f2aede";
        cyan = "#94e2d5"; brightCyan = "#6bd7ca";
        white = "#a6adc8"; brightWhite = "#bac2de";
      };
    };
    noctalia-catppuccin-light = {
      description = "Noctalia builtin Catppuccin (light)";
      bg = "#eff1f5";
      bgAlt = "#ccd0da";
      bgUrgent = "#d20f39";
      fg = "#4c4f69";
      fgDim = "#6c6f85";
      accent = "#8839ef";
      accentDim = "#fe640b";
      warn = "#40a02b";
      err = "#d20f39";
      border = "#a5adcb";
      ansi = {
        black = "#bcc0cc"; brightBlack = "#acb0be";
        red = "#d20f39"; brightRed = "#d20f39";
        green = "#40a02b"; brightGreen = "#40a02b";
        yellow = "#df8e1d"; brightYellow = "#df8e1d";
        blue = "#1e66f5"; brightBlue = "#1e66f5";
        magenta = "#ea76cb"; brightMagenta = "#ea76cb";
        cyan = "#179299"; brightCyan = "#179299";
        white = "#5c5f77"; brightWhite = "#6c6f85";
      };
    };
    noctalia-dracula-dark = {
      description = "Noctalia builtin Dracula (dark)";
      bg = "#282A36";
      bgAlt = "#44475A";
      bgUrgent = "#FF5555";
      fg = "#F8F8F2";
      fgDim = "#d6d8e0";
      accent = "#bd93f9";
      accentDim = "#ff79c6";
      warn = "#8be9fd";
      err = "#FF5555";
      border = "#5a5e77";
      ansi = {
        black = "#21222c"; brightBlack = "#6272a4";
        red = "#ff5555"; brightRed = "#ff6e6e";
        green = "#50fa7b"; brightGreen = "#69ff94";
        yellow = "#f1fa8c"; brightYellow = "#ffffa5";
        blue = "#bd93f9"; brightBlue = "#d6acff";
        magenta = "#ff79c6"; brightMagenta = "#ff92df";
        cyan = "#8be9fd"; brightCyan = "#a4ffff";
        white = "#f8f8f2"; brightWhite = "#ffffff";
      };
    };
    noctalia-dracula-light = {
      description = "Noctalia builtin Dracula (light)";
      bg = "#f8f8f2";
      bgAlt = "#e6e6ea";
      bgUrgent = "#FF5555";
      fg = "#282a36";
      fgDim = "#44475a";
      accent = "#8332f4";
      accentDim = "#ff1399";
      warn = "#0398b9";
      err = "#FF5555";
      border = "#cacad3";
      ansi = {
        black = "#f8f8f2"; brightBlack = "#6272a4";
        red = "#ff5555"; brightRed = "#ff6e6e";
        green = "#50fa7b"; brightGreen = "#69ff94";
        yellow = "#f1fa8c"; brightYellow = "#ffffa5";
        blue = "#bd93f9"; brightBlue = "#d6acff";
        magenta = "#ff79c6"; brightMagenta = "#ff92df";
        cyan = "#8be9fd"; brightCyan = "#a4ffff";
        white = "#282a36"; brightWhite = "#000000";
      };
    };
    noctalia-eldritch-dark = {
      description = "Noctalia builtin Eldritch (dark)";
      bg = "#212337";
      bgAlt = "#292e42";
      bgUrgent = "#f16c75";
      fg = "#ebfafa";
      fgDim = "#ABB4DA";
      accent = "#37f499";
      accentDim = "#04d1f9";
      warn = "#a48cf2";
      err = "#f16c75";
      border = "#3b4261";
      ansi = {
        black = "#21222c"; brightBlack = "#7081d0";
        red = "#f9515d"; brightRed = "#f16c75";
        green = "#37f499"; brightGreen = "#69F8B3";
        yellow = "#e9f941"; brightYellow = "#f1fc79";
        blue = "#9071f4"; brightBlue = "#a48cf2";
        magenta = "#f265b5"; brightMagenta = "#FD92CE";
        cyan = "#04d1f9"; brightCyan = "#66e4fd";
        white = "#ebfafa"; brightWhite = "#ffffff";
      };
    };
    noctalia-eldritch-light = {
      description = "Noctalia builtin Eldritch (light)";
      bg = "#f0f3f4";
      bgAlt = "#d5d9db";
      bgUrgent = "#fb5b66";
      fg = "#1e2029";
      fgDim = "#1e2029";
      accent = "#fb5bb6";
      accentDim = "#0ad6ff";
      warn = "#8a69f7";
      err = "#fb5b66";
      border = "#c9cbcd";
      ansi = {
        black = "#d5d9db"; brightBlack = "#c9cbcd";
        red = "#a03040"; brightRed = "#fb5b66";
        green = "#1a9960"; brightGreen = "#38ff9f";
        yellow = "#b3a010"; brightYellow = "#fff952";
        blue = "#2a3590"; brightBlue = "#5b73dc";
        magenta = "#8a2070"; brightMagenta = "#fb5bb6";
        cyan = "#007a99"; brightCyan = "#0ad6ff";
        white = "#1e2029"; brightWhite = "#1e2029";
      };
    };
    noctalia-gruvbox-dark = {
      description = "Noctalia builtin Gruvbox (dark)";
      bg = "#282828";
      bgAlt = "#3c3836";
      bgUrgent = "#fb4934";
      fg = "#fbf1c7";
      fgDim = "#ebdbb2";
      accent = "#b8bb26";
      accentDim = "#fabd2f";
      warn = "#83a598";
      err = "#fb4934";
      border = "#57514e";
      ansi = {
        black = "#282828"; brightBlack = "#928374";
        red = "#cc241d"; brightRed = "#fb4934";
        green = "#98971a"; brightGreen = "#b8bb26";
        yellow = "#d79921"; brightYellow = "#fabd2f";
        blue = "#458588"; brightBlue = "#83a598";
        magenta = "#b16286"; brightMagenta = "#d3869b";
        cyan = "#689d6a"; brightCyan = "#8ec07c";
        white = "#a89984"; brightWhite = "#ebdbb2";
      };
    };
    noctalia-gruvbox-light = {
      description = "Noctalia builtin Gruvbox (light)";
      bg = "#fbf1c7";
      bgAlt = "#ebdbb2";
      bgUrgent = "#cc241d";
      fg = "#3c3836";
      fgDim = "#7c6f64";
      accent = "#98971a";
      accentDim = "#d79921";
      warn = "#458588";
      err = "#cc241d";
      border = "#bdae93";
      ansi = {
        black = "#fbf1c7"; brightBlack = "#928374";
        red = "#cc241d"; brightRed = "#9d0006";
        green = "#98971a"; brightGreen = "#79740e";
        yellow = "#d79921"; brightYellow = "#b57614";
        blue = "#458588"; brightBlue = "#076678";
        magenta = "#b16286"; brightMagenta = "#8f3f71";
        cyan = "#689d6a"; brightCyan = "#427b58";
        white = "#7c6f64"; brightWhite = "#3c3836";
      };
    };
    noctalia-kanagawa-dark = {
      description = "Noctalia builtin Kanagawa (dark)";
      bg = "#1f1f28";
      bgAlt = "#2a2a37";
      bgUrgent = "#c34043";
      fg = "#c8c093";
      fgDim = "#717c7c";
      accent = "#76946a";
      accentDim = "#c0a36e";
      warn = "#7e9cd8";
      err = "#c34043";
      border = "#363646";
      ansi = {
        black = "#090618"; brightBlack = "#727169";
        red = "#c34043"; brightRed = "#e82424";
        green = "#76946a"; brightGreen = "#98bb6c";
        yellow = "#c0a36e"; brightYellow = "#e6c384";
        blue = "#7e9cd8"; brightBlue = "#7fb4ca";
        magenta = "#957fb8"; brightMagenta = "#938aa9";
        cyan = "#6a9589"; brightCyan = "#7aa89f";
        white = "#c8c093"; brightWhite = "#dcd7ba";
      };
    };
    noctalia-kanagawa-light = {
      description = "Noctalia builtin Kanagawa (light)";
      bg = "#f2ecbc";
      bgAlt = "#e5ddb0";
      bgUrgent = "#c84053";
      fg = "#545464";
      fgDim = "#8a8980";
      accent = "#6f894e";
      accentDim = "#77713f";
      warn = "#4d699b";
      err = "#c84053";
      border = "#cfc49c";
      ansi = {
        black = "#1F1F28"; brightBlack = "#8a8980";
        red = "#c84053"; brightRed = "#d7474b";
        green = "#6f894e"; brightGreen = "#6e915f";
        yellow = "#77713f"; brightYellow = "#836f4a";
        blue = "#4d699b"; brightBlue = "#6693bf";
        magenta = "#b35b79"; brightMagenta = "#624c83";
        cyan = "#597b75"; brightCyan = "#5e857a";
        white = "#545464"; brightWhite = "#43436c";
      };
    };
    noctalia-noctalia-dark = {
      description = "Noctalia builtin Noctalia (dark)";
      bg = "#070722";
      bgAlt = "#11112d";
      bgUrgent = "#FD4663";
      fg = "#f3edf7";
      fgDim = "#7c80b4";
      accent = "#fff59b";
      accentDim = "#a9aefe";
      warn = "#9BFECE";
      err = "#FD4663";
      border = "#21215F";
      ansi = {
        black = "#11112d"; brightBlack = "#21215F";
        red = "#FD4663"; brightRed = "#FD4663";
        green = "#9BFECE"; brightGreen = "#9BFECE";
        yellow = "#fff59b"; brightYellow = "#fff59b";
        blue = "#a9aefe"; brightBlue = "#a9aefe";
        magenta = "#FD4663"; brightMagenta = "#FD4663";
        cyan = "#9BFECE"; brightCyan = "#9BFECE";
        white = "#f3edf7"; brightWhite = "#ffffff";
      };
    };
    noctalia-noctalia-light = {
      description = "Noctalia builtin Noctalia (light)";
      bg = "#e6e8fa";
      bgAlt = "#eff0ff";
      bgUrgent = "#FD4663";
      fg = "#0e0e43";
      fgDim = "#4b55c8";
      accent = "#5d65f5";
      accentDim = "#8E93D8";
      warn = "#0e0e43";
      err = "#FD4663";
      border = "#8288fc";
      ansi = {
        black = "#eff0ff"; brightBlack = "#8288fc";
        red = "#FD4663"; brightRed = "#FD4663";
        green = "#0e0e43"; brightGreen = "#0e0e43";
        yellow = "#5d65f5"; brightYellow = "#5d65f5";
        blue = "#8E93D8"; brightBlue = "#8E93D8";
        magenta = "#FD4663"; brightMagenta = "#FD4663";
        cyan = "#0e0e43"; brightCyan = "#0e0e43";
        white = "#4b55c8"; brightWhite = "#0e0e43";
      };
    };
    noctalia-nord-dark = {
      description = "Noctalia builtin Nord (dark)";
      bg = "#2e3440";
      bgAlt = "#3b4252";
      bgUrgent = "#bf616a";
      fg = "#eceff4";
      fgDim = "#d8dee9";
      accent = "#8fbcbb";
      accentDim = "#88c0d0";
      warn = "#5e81ac";
      err = "#bf616a";
      border = "#505a70";
      ansi = {
        black = "#3b4252"; brightBlack = "#596377";
        red = "#bf616a"; brightRed = "#bf616a";
        green = "#a3be8c"; brightGreen = "#a3be8c";
        yellow = "#ebcb8b"; brightYellow = "#ebcb8b";
        blue = "#81a1c1"; brightBlue = "#81a1c1";
        magenta = "#b48ead"; brightMagenta = "#b48ead";
        cyan = "#88c0d0"; brightCyan = "#8fbcbb";
        white = "#e5e9f0"; brightWhite = "#eceff4";
      };
    };
    noctalia-nord-light = {
      description = "Noctalia builtin Nord (light)";
      bg = "#eceff4";
      bgAlt = "#e5e9f0";
      bgUrgent = "#bf616a";
      fg = "#2e3440";
      fgDim = "#4c566a";
      accent = "#5e81ac";
      accentDim = "#64adc2";
      warn = "#6fa9a8";
      err = "#bf616a";
      border = "#c5cedd";
      ansi = {
        black = "#3b4252"; brightBlack = "#4c566a";
        red = "#bf616a"; brightRed = "#bf616a";
        green = "#96b17f"; brightGreen = "#96b17f";
        yellow = "#c5a565"; brightYellow = "#c5a565";
        blue = "#81a1c1"; brightBlue = "#81a1c1";
        magenta = "#b48ead"; brightMagenta = "#b48ead";
        cyan = "#7bb3c3"; brightCyan = "#82afae";
        white = "#a5abb6"; brightWhite = "#eceff4";
      };
    };
    noctalia-rose-pine-dark = {
      description = "Noctalia builtin Rosé Pine (dark)";
      bg = "#191724";
      bgAlt = "#26233a";
      bgUrgent = "#eb6f92";
      fg = "#e0def4";
      fgDim = "#908caa";
      accent = "#ebbcba";
      accentDim = "#9ccfd8";
      warn = "#31748f";
      err = "#eb6f92";
      border = "#403d52";
      ansi = {
        black = "#26233a"; brightBlack = "#6e6a86";
        red = "#eb6f92"; brightRed = "#eb6f92";
        green = "#31748f"; brightGreen = "#31748f";
        yellow = "#f6c177"; brightYellow = "#f6c177";
        blue = "#9ccfd8"; brightBlue = "#9ccfd8";
        magenta = "#c4a7e7"; brightMagenta = "#c4a7e7";
        cyan = "#ebbcba"; brightCyan = "#ebbcba";
        white = "#e0def4"; brightWhite = "#e0def4";
      };
    };
    noctalia-rose-pine-light = {
      description = "Noctalia builtin Rosé Pine (light)";
      bg = "#fffaf3";
      bgAlt = "#f2e9e1";
      bgUrgent = "#b4637a";
      fg = "#575279";
      fgDim = "#797593";
      accent = "#d7827e";
      accentDim = "#56949f";
      warn = "#286983";
      err = "#b4637a";
      border = "#dfdad9";
      ansi = {
        black = "#f2e9e1"; brightBlack = "#9893a5";
        red = "#b4637a"; brightRed = "#b4637a";
        green = "#286983"; brightGreen = "#286983";
        yellow = "#ea9d34"; brightYellow = "#ea9d34";
        blue = "#56949f"; brightBlue = "#56949f";
        magenta = "#907aa9"; brightMagenta = "#907aa9";
        cyan = "#d7827e"; brightCyan = "#d7827e";
        white = "#575279"; brightWhite = "#575279";
      };
    };
    noctalia-tokyo-night-dark = {
      description = "Noctalia builtin Tokyo-Night (dark)";
      bg = "#1a1b26";
      bgAlt = "#24283b";
      bgUrgent = "#f7768e";
      fg = "#c0caf5";
      fgDim = "#9aa5ce";
      accent = "#7aa2f7";
      accentDim = "#bb9af7";
      warn = "#9ece6a";
      err = "#f7768e";
      border = "#353D57";
      ansi = {
        black = "#15161e"; brightBlack = "#414868";
        red = "#f7768e"; brightRed = "#f7768e";
        green = "#9ece6a"; brightGreen = "#9ece6a";
        yellow = "#e0af68"; brightYellow = "#e0af68";
        blue = "#7aa2f7"; brightBlue = "#7aa2f7";
        magenta = "#bb9af7"; brightMagenta = "#bb9af7";
        cyan = "#7dcfff"; brightCyan = "#7dcfff";
        white = "#a9b1d6"; brightWhite = "#c0caf5";
      };
    };
    noctalia-tokyo-night-light = {
      description = "Noctalia builtin Tokyo-Night (light)";
      bg = "#e1e2e7";
      bgAlt = "#d0d5e3";
      bgUrgent = "#f52a65";
      fg = "#3760bf";
      fgDim = "#6172b0";
      accent = "#2e7de9";
      accentDim = "#9854f1";
      warn = "#587539";
      err = "#f52a65";
      border = "#b4b5b9";
      ansi = {
        black = "#e9e9ed"; brightBlack = "#a1a6c5";
        red = "#f52a65"; brightRed = "#f52a65";
        green = "#587539"; brightGreen = "#587539";
        yellow = "#8c6c3e"; brightYellow = "#8c6c3e";
        blue = "#2e7de9"; brightBlue = "#2e7de9";
        magenta = "#9854f1"; brightMagenta = "#9854f1";
        cyan = "#007197"; brightCyan = "#007197";
        white = "#6172b0"; brightWhite = "#3760bf";
      };
    };
  };
}
