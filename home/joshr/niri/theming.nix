{ config, lib, pkgs, ... }:

# Renders each palette in themes.nix into the config formats niri, waybar,
# wofi and dunst actually read, and exposes them as one store path per theme.
#
# How runtime switching stays declarative
# ---------------------------------------
# home-manager owns ~/.config/... as read-only symlinks into the store, so a
# switcher script can't rewrite them. Instead every theme is built ahead of
# time and the only mutable state is a single symlink:
#
#     ~/.local/state/niri-theme/active -> /nix/store/...-niri-theme-<name>
#
# Each tool is pointed at a file underneath that symlink through its own
# indirection mechanism:
#
#   niri    `include` node, and niri live-reloads its config on change
#   waybar  GTK CSS `@import`, reloaded with SIGUSR2
#   wofi    GTK CSS `@import`, read fresh on each launch
#   dunst   `services.dunst.configFile`, which becomes `dunst -config <path>`
#
# So all content is in the Nix store; the only thing that changes at runtime
# is where one symlink points.
let
  themeSet = import ./themes.nix { inherit lib; };
  inherit (themeSet) themes;

  stateDir = "${config.home.homeDirectory}/.local/state/niri-theme";
  activeDir = "${stateDir}/active";

  # niri KDL fragment: focus ring, borders, overview backdrop.
  renderNiri = t: ''
    // Generated from home/joshr/niri/themes.nix — theme "${t.name}".
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

  # Waybar colours only. Layout/geometry lives in the static style.css so it
  # doesn't get duplicated across themes.
  renderWaybarCss = t: ''
    /* Generated from themes.nix — theme "${t.name}". */
    @define-color bg        ${t.bg};
    @define-color bg-alt    ${t.bgAlt};
    @define-color bg-urgent ${t.bgUrgent};
    @define-color fg        ${t.fg};
    @define-color fg-dim    ${t.fgDim};
    @define-color accent    ${t.accent};
    @define-color accent-dim ${t.accentDim};
    @define-color warn      ${t.warn};
    @define-color err       ${t.err};
    @define-color border    ${t.border};
  '';

  renderWofiCss = t: ''
    /* Generated from themes.nix — theme "${t.name}". */
    @define-color bg        ${t.bg};
    @define-color bg-alt    ${t.bgAlt};
    @define-color fg        ${t.fg};
    @define-color fg-dim    ${t.fgDim};
    @define-color accent    ${t.accent};
    @define-color border    ${t.border};
  '';

  # dunst has no include mechanism, so the whole file is rendered per theme
  # and selected via `dunst -config`.
  renderDunstrc = t: ''
    # Generated from home/joshr/niri/themes.nix — theme "${t.name}".
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

  # swaylock is launched with flags rather than a config file, so its palette
  # is emitted as a shell fragment the lock script sources.
  renderSwaylockEnv = t: ''
    # Generated from themes.nix — theme "${t.name}".
    LOCK_BG=${lib.removePrefix "#" t.bg}
    LOCK_ACCENT=${lib.removePrefix "#" t.accent}
    LOCK_ACCENT_DIM=${lib.removePrefix "#" t.accentDim}
    LOCK_FG=${lib.removePrefix "#" t.fg}
    LOCK_FG_DIM=${lib.removePrefix "#" t.fgDim}
    LOCK_ERR=${lib.removePrefix "#" t.err}
    LOCK_WARN=${lib.removePrefix "#" t.warn}
  '';

  mkThemeDir =
    t:
    pkgs.runCommand "niri-theme-${t.name}" { } ''
      mkdir -p "$out"
      cp ${pkgs.writeText "niri.kdl" (renderNiri t)}         "$out/niri.kdl"
      cp ${pkgs.writeText "waybar.css" (renderWaybarCss t)}  "$out/waybar.css"
      cp ${pkgs.writeText "wofi.css" (renderWofiCss t)}      "$out/wofi.css"
      cp ${pkgs.writeText "dunstrc" (renderDunstrc t)}       "$out/dunstrc"
      cp ${pkgs.writeText "swaylock.env" (renderSwaylockEnv t)} "$out/swaylock.env"
      echo -n "${t.name}" > "$out/name"
    '';

  themeDirs = lib.mapAttrs (_: mkThemeDir) themes;
in
{
  # Consumed by the other modules in this directory.
  _module.args.niriTheming = {
    inherit
      themeSet
      themes
      themeDirs
      stateDir
      activeDir
      ;
    defaultTheme = themeSet.default;
    defaultThemeDir = themeDirs.${themeSet.default};
  };

  # Seed the symlink on first activation so a fresh login has a theme even
  # before the switcher has ever run. Existing choices are left alone.
  home.activation.seedNiriTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${activeDir}" ]; then
      $DRY_RUN_CMD mkdir -p "${stateDir}"
      $DRY_RUN_CMD ln -sfn "${themeDirs.${themeSet.default}}" "${activeDir}"
      $DRY_RUN_CMD sh -c 'printf %s "${themeSet.default}" > "${stateDir}/current"'
    fi
  '';
}
