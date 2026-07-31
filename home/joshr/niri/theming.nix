{ config, lib, pkgs, ... }:

# Renders each palette in themes.nix into the config formats niri, waybar,
# wofi, dunst and swaylock actually read, and exposes them as one store path
# per theme.
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
    #battery:hover {
      background-color: alpha(@accent, 0.14);
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
      echo -n "${name}" > "$out/name"
    '';

  themeDirs = lib.mapAttrs mkThemeDir themes;
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

  # Seed the symlink on first activation so a fresh login has a theme before
  # the switcher has ever run. An existing choice is left alone.
  home.activation.seedNiriTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${activeDir}" ]; then
      $DRY_RUN_CMD mkdir -p "${stateDir}"
      $DRY_RUN_CMD ln -sfn "${themeDirs.${themeSet.default}}" "${activeDir}"
      $DRY_RUN_CMD sh -c 'printf %s "${themeSet.default}" > "${stateDir}/current"'
    fi
  '';
}
