{ config, lib, pkgs, ... }:

# Renders each palette in themes.nix into the config formats niri, waybar,
# wofi, dunst, kitty, KDE and swaylock actually read, and exposes them as one
# store path per theme.
#
# How runtime switching stays declarative
# ---------------------------------------
# home-manager owns ~/.config/... as read-only symlinks into the store, so a
# switcher script can't rewrite them. Instead every theme is built ahead of
# time and the only mutable state is a single symlink:
#
#     ~/.local/state/niri-theme/active -> /nix/store/...-niri-theme-<name>
#
# Each tool is pointed at a file underneath that symlink:
#
#   niri     `include` node, live-reloaded when the target changes
#   waybar   started with `-s <path>`, restarted by the switcher
#   wofi     `style` key in its config, re-read on every launch
#   dunst    `services.dunst.configFile`, restarted by the switcher
#   kitty    `include` at the end of kitty.conf, reloaded on SIGUSR1
#   KDE apps `~/.config/kdeglobals` symlink, re-read at app startup
#
# Note these are *complete* files, not colour fragments. An earlier version
# emitted only `@define-color` blocks and pulled them in with a GTK CSS
# `@import`; that adds a resolution step that can silently no-op, and the
# whole stylesheet is generated anyway, so there is nothing to gain from it.
let
  themeSet = import ./themes.nix { inherit lib; };
  inherit (themeSet) themes;

  stateDir = "${config.home.homeDirectory}/.local/state/niri-theme";
  activeDir = "${stateDir}/active";

  # niri KDL fragment: focus ring, borders, overview backdrop.
  renderNiri = name: t: ''
    // Generated from home/joshr/niri/themes.nix — theme "${name}".
    // Included by config.kdl; niri reloads automatically when this changes.
    layout {
        focus-ring {
            width 2
            active-color "${t.accent}"
            inactive-color "${t.accentDim}"
        }

        border {
            off
            width 2
            active-color "${t.accent}"
            inactive-color "${t.bgAlt}"
        }

        shadow {
            on
            softness 24
            spread 3
            offset x=0 y=4
            color "#00000070"
        }

        insert-hint {
            color "${t.accent}80"
        }
    }

    overview {
        backdrop-color "${t.bg}"
    }
  '';

  # Complete waybar stylesheet. Layout and colour together, so a theme switch
  # is just "point waybar at a different file and restart it".
  renderWaybarCss = name: t: ''
    /* Generated from home/joshr/niri/themes.nix — theme "${name}". */
    @define-color bg         ${t.bg};
    @define-color bg-alt     ${t.bgAlt};
    @define-color bg-urgent  ${t.bgUrgent};
    @define-color fg         ${t.fg};
    @define-color fg-dim     ${t.fgDim};
    @define-color accent     ${t.accent};
    @define-color accent-dim ${t.accentDim};
    @define-color warn       ${t.warn};
    @define-color err        ${t.err};
    @define-color bordercol  ${t.border};

    * {
      font-family: "FiraCode Nerd Font", "Noto Sans", sans-serif;
      font-size: 13px;
      font-weight: 500;
      border: none;
      border-radius: 0;
      min-height: 0;
    }

    window#waybar {
      background: transparent;
      color: @fg;
    }

    /* Each group is its own floating pill rather than one long bar. */
    .modules-left,
    .modules-center,
    .modules-right {
      background-color: alpha(@bg, 0.88);
      border: 1px solid alpha(@accent-dim, 0.55);
      border-radius: 12px;
      padding: 0 6px;
    }

    #workspaces {
      padding: 0 2px;
    }

    #workspaces button {
      padding: 0 9px;
      margin: 4px 2px;
      color: @fg-dim;
      background: transparent;
      border-radius: 8px;
      transition: background-color 160ms ease, color 160ms ease;
    }

    #workspaces button:hover {
      background-color: alpha(@accent, 0.15);
      color: @fg;
      box-shadow: none;
      text-shadow: none;
    }

    #workspaces button.active {
      background-color: @accent;
      color: @bg;
      font-weight: 700;
    }

    #workspaces button.urgent {
      background-color: @err;
      color: @bg;
    }

    #window {
      padding: 0 10px;
      color: @fg;
    }

    window#waybar.empty #window {
      padding: 0;
      margin: 0;
      background: transparent;
    }

    #clock {
      padding: 0 16px;
      color: @accent;
      font-weight: 700;
    }

    #tray,
    #pulseaudio,
    #network,
    #battery,
    #custom-idle-inhibitor,
    #custom-session {
      padding: 0 10px;
      margin: 4px 1px;
      border-radius: 8px;
      color: @fg;
    }

    #tray > .passive {
      -gtk-icon-effect: dim;
    }

    #tray > .needs-attention {
      -gtk-icon-effect: highlight;
      background-color: @err;
      border-radius: 8px;
    }

    #pulseaudio:hover,
    #network:hover,
    #battery:hover,
    #custom-idle-inhibitor:hover {
      background-color: alpha(@accent, 0.14);
    }

    /* Dim when idling is normal, lit when the machine is being held awake —
       the inhibitor is a mode you can forget you left on, so it should be
       obvious at a glance. */
    #custom-idle-inhibitor {
      color: @fg-dim;
      font-size: 15px;
    }

    #custom-idle-inhibitor.activated {
      color: @warn;
    }

    #pulseaudio.muted {
      color: @fg-dim;
    }

    #network.disconnected {
      color: @err;
    }

    #battery.warning:not(.charging) {
      color: @warn;
    }

    #battery.critical:not(.charging) {
      color: @bg;
      background-color: @err;
    }

    #custom-session {
      color: @accent;
      font-size: 15px;
      padding: 0 12px;
    }

    #custom-session:hover {
      background-color: @err;
      color: @bg;
    }

    tooltip {
      background-color: @bg;
      border: 1px solid @accent-dim;
      border-radius: 10px;
    }

    tooltip label {
      color: @fg;
      padding: 4px;
    }
  '';

  # Complete wofi stylesheet.
  renderWofiCss = name: t: ''
    /* Generated from home/joshr/niri/themes.nix — theme "${name}". */
    @define-color bg         ${t.bg};
    @define-color bg-alt     ${t.bgAlt};
    @define-color fg         ${t.fg};
    @define-color fg-dim     ${t.fgDim};
    @define-color accent     ${t.accent};
    @define-color bordercol  ${t.border};

    * {
      font-family: "FiraCode Nerd Font", "Noto Sans", sans-serif;
      font-size: 14px;
    }

    window {
      background-color: alpha(@bg, 0.96);
      border: 1px solid @accent;
      border-radius: 14px;
    }

    #outer-box {
      padding: 14px;
    }

    #input {
      background-color: @bg-alt;
      color: @fg;
      border: 1px solid @bordercol;
      border-radius: 10px;
      padding: 9px 12px;
      margin-bottom: 12px;
    }

    #input:focus {
      border-color: @accent;
    }

    #input image {
      color: @accent;
    }

    #scroll {
      margin: 0;
    }

    #inner-box {
      background-color: transparent;
    }

    #entry {
      padding: 8px 10px;
      border-radius: 9px;
      color: @fg;
      background-color: transparent;
    }

    #entry:selected {
      background-color: @accent;
      color: @bg;
      font-weight: 700;
    }

    #entry image {
      margin-right: 10px;
    }

    #text {
      color: inherit;
    }

    #text:selected {
      color: @bg;
    }

    #entry #text mark {
      background-color: transparent;
      color: @accent;
      font-weight: 700;
    }

    #entry:selected #text mark {
      color: @bg;
      text-decoration: underline;
    }
  '';

  renderDunstrc = name: t: ''
    # Generated from home/joshr/niri/themes.nix — theme "${name}".
    [global]
        monitor = 0
        follow = mouse
        width = (300, 460)
        height = (0, 320)
        origin = top-right
        offset = (16, 16)
        scale = 0
        notification_limit = 6
        progress_bar = true
        progress_bar_height = 8
        progress_bar_frame_width = 1
        progress_bar_min_width = 150
        progress_bar_max_width = 400
        indicate_hidden = yes
        transparency = 8
        separator_height = 2
        padding = 14
        horizontal_padding = 16
        text_icon_padding = 12
        frame_width = 2
        frame_color = "${t.accentDim}"
        separator_color = frame
        sort = yes
        font = FiraCode Nerd Font 10
        line_height = 0
        markup = full
        format = "<b>%s</b>\n%b"
        alignment = left
        vertical_alignment = center
        show_age_threshold = 60
        ellipsize = middle
        ignore_newline = no
        stack_duplicates = true
        hide_duplicate_count = false
        show_indicators = yes
        enable_recursive_icon_lookup = true
        icon_theme = "Papirus-Dark"
        icon_position = left
        min_icon_size = 24
        max_icon_size = 48
        sticky_history = yes
        history_length = 40
        corner_radius = 10
        mouse_left_click = do_action, close_current
        mouse_middle_click = close_all
        mouse_right_click = close_current

    [urgency_low]
        background = "${t.bg}"
        foreground = "${t.fgDim}"
        frame_color = "${t.accentDim}"
        timeout = 5

    [urgency_normal]
        background = "${t.bg}"
        foreground = "${t.fg}"
        frame_color = "${t.accent}"
        timeout = 8

    [urgency_critical]
        background = "${t.bgUrgent}"
        foreground = "${t.fg}"
        frame_color = "${t.err}"
        timeout = 0
  '';

  # "#rrggbb" -> "r,g,b". KDE colour keys are decimal triples, not hex.
  rgb =
    hex:
    let
      h = lib.removePrefix "#" hex;
      byte = start: toString (lib.fromHexString (builtins.substring start 2 h));
    in
    "${byte 0},${byte 2},${byte 4}";

  # kdeglobals, so KDE apps — Dolphin in particular — follow the palette.
  #
  # KDE apps read their colour scheme from kdeglobals via KColorScheme
  # whether or not Plasma is running, so this works in a bare niri session
  # with no KDE desktop underneath it.
  renderKdeglobals = name: t: ''
    # Generated from home/joshr/niri/themes.nix — theme "${name}".
    [General]
    ColorScheme=niri-${name}
    AccentColor=${rgb t.accent}
    accentColorFromWallpaper=false

    [Icons]
    Theme=Papirus-Dark

    [KDE]
    widgetStyle=Breeze

    [Colors:Window]
    BackgroundNormal=${rgb t.bg}
    BackgroundAlternate=${rgb t.bgAlt}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    ForegroundLink=${rgb t.accent}
    ForegroundVisited=${rgb t.accentDim}
    ForegroundNegative=${rgb t.err}
    ForegroundNeutral=${rgb t.warn}
    ForegroundPositive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:View]
    BackgroundNormal=${rgb t.bg}
    BackgroundAlternate=${rgb t.bgAlt}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    ForegroundLink=${rgb t.accent}
    ForegroundVisited=${rgb t.accentDim}
    ForegroundNegative=${rgb t.err}
    ForegroundNeutral=${rgb t.warn}
    ForegroundPositive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:Button]
    BackgroundNormal=${rgb t.bgAlt}
    BackgroundAlternate=${rgb t.bg}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    ForegroundLink=${rgb t.accent}
    ForegroundVisited=${rgb t.accentDim}
    ForegroundNegative=${rgb t.err}
    ForegroundNeutral=${rgb t.warn}
    ForegroundPositive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:Selection]
    BackgroundNormal=${rgb t.accent}
    BackgroundAlternate=${rgb t.accentDim}
    ForegroundNormal=${rgb t.bg}
    ForegroundInactive=${rgb t.bgAlt}
    ForegroundActive=${rgb t.bg}
    ForegroundLink=${rgb t.bg}
    ForegroundVisited=${rgb t.bgAlt}
    ForegroundNegative=${rgb t.err}
    ForegroundNeutral=${rgb t.warn}
    ForegroundPositive=${rgb t.bg}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:Tooltip]
    BackgroundNormal=${rgb t.bgAlt}
    BackgroundAlternate=${rgb t.bg}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:Complementary]
    BackgroundNormal=${rgb t.bg}
    BackgroundAlternate=${rgb t.bgAlt}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:Header]
    BackgroundNormal=${rgb t.bgAlt}
    BackgroundAlternate=${rgb t.bg}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [WM]
    activeBackground=${rgb t.bg}
    activeForeground=${rgb t.fg}
    inactiveBackground=${rgb t.bgAlt}
    inactiveForeground=${rgb t.fgDim}
  '';

  # Fallback terminal palette for a theme with no `ansi` block.
  #
  # The ten roles have no blue, magenta or cyan in them, so those three have
  # to borrow the accent — the result is legible but flat, and anything that
  # colour-codes by hue (git diff, ls, syntax highlighting) loses most of its
  # distinctions. Every theme in themes.nix defines `ansi` for that reason;
  # this exists so adding one without it degrades instead of failing.
  deriveAnsi = t: {
    black = t.bg;          brightBlack = t.fgDim;
    red = t.err;           brightRed = t.err;
    green = t.accent;      brightGreen = t.accent;
    yellow = t.warn;       brightYellow = t.warn;
    blue = t.accentDim;    brightBlue = t.accent;
    magenta = t.accentDim; brightMagenta = t.accent;
    cyan = t.accentDim;    brightCyan = t.accent;
    white = t.fg;          brightWhite = t.fg;
  };

  # kitty colours. Only colours — kitty.nix keeps font, padding, opacity and
  # the rest, and this is `include`d after them so a theme switch can't
  # disturb any of that.
  renderKitty =
    name: t:
    let
      a = t.ansi or (deriveAnsi t);
    in
    ''
      # Generated from home/joshr/niri/themes.nix — theme "${name}".
      # Included by kitty.conf; reloaded in place on SIGUSR1.

      foreground           ${t.fg}
      background           ${t.bg}
      selection_foreground ${t.bg}
      selection_background ${t.accent}

      cursor               ${t.accent}
      cursor_text_color    ${t.bg}

      url_color            ${t.accent}

      # Window borders only show with more than one kitty split.
      active_border_color   ${t.accent}
      inactive_border_color ${t.border}
      bell_border_color     ${t.err}

      active_tab_foreground   ${t.bg}
      active_tab_background   ${t.accent}
      inactive_tab_foreground ${t.fgDim}
      inactive_tab_background ${t.bgAlt}
      tab_bar_background      ${t.bg}

      mark1_foreground ${t.bg}
      mark1_background ${t.accent}

      color0  ${a.black}
      color8  ${a.brightBlack}
      color1  ${a.red}
      color9  ${a.brightRed}
      color2  ${a.green}
      color10 ${a.brightGreen}
      color3  ${a.yellow}
      color11 ${a.brightYellow}
      color4  ${a.blue}
      color12 ${a.brightBlue}
      color5  ${a.magenta}
      color13 ${a.brightMagenta}
      color6  ${a.cyan}
      color14 ${a.brightCyan}
      color7  ${a.white}
      color15 ${a.brightWhite}
    '';

  # swaylock takes flags, not a config file, so its palette is a shell
  # fragment the lock script sources.
  renderSwaylockEnv = name: t: ''
    # Generated from home/joshr/niri/themes.nix — theme "${name}".
    LOCK_BG=${lib.removePrefix "#" t.bg}
    LOCK_ACCENT=${lib.removePrefix "#" t.accent}
    LOCK_ACCENT_DIM=${lib.removePrefix "#" t.accentDim}
    LOCK_FG=${lib.removePrefix "#" t.fg}
    LOCK_FG_DIM=${lib.removePrefix "#" t.fgDim}
    LOCK_ERR=${lib.removePrefix "#" t.err}
    LOCK_WARN=${lib.removePrefix "#" t.warn}
  '';

  # sddm-astronaut's themeConfig, so the login screen matches. Consumed by
  # modules/nixos/niri.nix, which builds one themed package per palette.
  sddmThemeConfig = t: {
    FullBlur = "false";
    PartialBlur = "true";
    BlurRadius = "60";
    DimBackground = "0.25";
    CropBackground = "true";

    HeaderText = "Welcome";
    HourFormat = "HH:mm";
    DateFormat = "dddd, d MMMM";
    FormPosition = "center";

    HeaderTextColor = t.accent;
    DateTextColor = t.fg;
    TimeTextColor = t.accent;
    FormBackgroundColor = t.bg;
    BackgroundColor = t.bg;
    DimBackgroundColor = "#000000";
    LoginFieldBackgroundColor = t.bgAlt;
    PasswordFieldBackgroundColor = t.bgAlt;
    LoginFieldTextColor = t.fg;
    PasswordFieldTextColor = t.fg;
    UserIconColor = t.accent;
    PasswordIconColor = t.accent;
    PlaceholderTextColor = t.fgDim;
    WarningColor = t.err;
    LoginButtonTextColor = t.bg;
    LoginButtonBackgroundColor = t.accent;
    SystemButtonsIconsColor = t.accent;
    SessionButtonTextColor = t.fg;
    VirtualKeyboardButtonTextColor = t.fg;
    DropdownTextColor = t.fg;
    DropdownSelectedBackgroundColor = t.accentDim;
    DropdownBackgroundColor = t.bgAlt;
    HighlightTextColor = t.bg;
    HighlightBackgroundColor = t.accent;
    HighlightBorderColor = t.accent;
    HoverUserIconColor = t.fg;
    HoverSystemButtonsIconsColor = t.fg;

    Font = "FiraCode Nerd Font";
    FontSize = "11";
  };

  mkThemeDir =
    name: t:
    pkgs.runCommand "niri-theme-${name}" { } ''
      mkdir -p "$out"
      cp ${pkgs.writeText "niri.kdl" (renderNiri name t)}            "$out/niri.kdl"
      cp ${pkgs.writeText "waybar.css" (renderWaybarCss name t)}     "$out/waybar.css"
      cp ${pkgs.writeText "wofi.css" (renderWofiCss name t)}         "$out/wofi.css"
      cp ${pkgs.writeText "dunstrc" (renderDunstrc name t)}          "$out/dunstrc"
      cp ${pkgs.writeText "swaylock.env" (renderSwaylockEnv name t)} "$out/swaylock.env"
      cp ${pkgs.writeText "kdeglobals" (renderKdeglobals name t)}     "$out/kdeglobals"
      cp ${pkgs.writeText "kitty.conf" (renderKitty name t)}          "$out/kitty.conf"
      echo -n "${name}" > "$out/name"
    '';

  themeDirs = lib.mapAttrs mkThemeDir themes;

  # `name) target="/nix/store/..." ;;` arms for the activation script's case.
  themeCaseArms = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (n: d: "      ${n}) target=\"${d}\" ;;") themeDirs
  );
in
{
  _module.args.niriTheming = {
    inherit
      themeSet
      themes
      themeDirs
      stateDir
      activeDir
      sddmThemeConfig
      ;
    defaultTheme = themeSet.default;
    defaultThemeDir = themeDirs.${themeSet.default};
  };

  # Re-point the symlink at the *current generation's* store path for whichever
  # theme is selected, on every activation.
  #
  # This deliberately does more than seed-if-missing. Each rebuild produces new
  # store paths for the themes, but the symlink would still point into the old
  # generation — so edits to themes.nix (or to any of the renderers above)
  # would appear to do nothing until the theme was switched by hand, and would
  # break outright once the old path was garbage collected.
  #
  # The selected theme *name* is preserved; only the path it resolves to is
  # refreshed. An unknown or missing name falls back to the default.
  home.activation.linkNiriTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "${stateDir}"

    current="$(cat "${stateDir}/current" 2>/dev/null || true)"
    case "$current" in
${themeCaseArms}
      *) target="${themeDirs.${themeSet.default}}"; current="${themeSet.default}" ;;
    esac

    $DRY_RUN_CMD ln -sfn "$target" "${activeDir}"
    $DRY_RUN_CMD sh -c "printf %s '$current' > '${stateDir}/current'"
  '';
}
