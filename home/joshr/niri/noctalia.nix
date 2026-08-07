{
  config,
  lib,
  pkgs,
  niriScripts,
  ...
}:

# noctalia: the whole session shell in one process, as an alternative to the
# waybar stack.
#
# What this replaces
# ------------------
# The niri session is a compositor and nothing else, so everything around it
# had to be assembled from single-purpose daemons — waybar for the bar, dunst
# for notifications, swayosd for the volume/brightness pop-up, wofi for the
# launcher and every menu, cliphist for clipboard history, swayidle for the
# idle timers, swaylock/hyprlock for the lock screen, awww for the wallpaper.
# Eight programs, eight config formats, and a theme switcher whose job was
# largely to restart them all in the right order.
#
# noctalia is all of those in one process reading one TOML file:
#
#     waybar    -> [bar.main] and the widget list below
#     dunst     -> [notification]
#     swayosd   -> [osd]
#     wofi      -> [shell.launcher]
#     cliphist  -> [shell] clipboard_*
#     swayidle  -> [idle.behavior.*]
#     hyprlock  -> [lockscreen] and [lockscreen_widgets]
#     awww      -> [wallpaper]
#
# No home-manager module, and no flake input
# ------------------------------------------
# The shell starts from `pkgs.noctalia` and everything below is written out
# by hand. Small source patches add lock-screen entrance/exit motion, let text
# OSDs grow to their content, use username@host in the control centre, and
# expose relative MPRIS volume actions — behaviours v5 does not expose as
# settings —
# so the first rebuild after this change compiles Noctalia locally; later
# builds reuse that store result.
# Upstream ships a home-manager module in its flake, and this used to use it,
# but it only generates the three files at the bottom of this comment and its
# flake publishes no substituter — so having it in `inputs` meant an extra
# lock entry, and any accidental reference to `packages.default` meant
# compiling a Qt/C++ project locally. What it generates is small enough to own:
#
#     ~/.config/noctalia/config.toml       from `settings`
#     ~/.config/noctalia/palettes/*.json   one per theme, from themes.nix
#     the systemd user service
#
# **Watch the attribute name.** nixpkgs carries both majors and they read
# backwards: `pkgs.noctalia` is the v5 line, which is what everything here is
# written against, and `pkgs.noctalia-shell` is 4.7.7 — it kept the
# repository's old name, which upstream changed to `noctalia` at v5. The v4
# config schema is different enough that the wrong one comes up with most of
# this ignored.
let
  useNoctalia = config.local.niri.shell == "noctalia";

  pkg = pkgs.noctalia.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./noctalia-lock-transition.patch
      ./noctalia-user-media.patch
    ];
  });
  noctalia = lib.getExe pkg;

  paletteSet = import ./noctalia-palettes.nix { inherit lib; };

  tomlFormat = pkgs.formats.toml { };
  jsonFormat = pkgs.formats.json { };

  # The same directories the scripts in ./scripts.nix use, spelled the same
  # way. `resolvedThemeFile` in particular is the fan-out point: the SDDM sync
  # in modules/nixos/niri.nix and the Limine sync in modules/nixos/boot.nix
  # both watch it and both read their palette out of it, and it is the one
  # description of a colour scheme that survives leaving this user's session.
  stateDir = "${config.home.homeDirectory}/.local/state/niri-theme";
  resolvedThemeFile = "${stateDir}/noctalia-resolved";
  liveThemeDir = "${stateDir}/noctalia-live";
  activeThemeDir = "${stateDir}/active";
  spotifyThemeDir = "${config.home.homeDirectory}/.local/state/noctalia-spotify";
  wallpaperDir = "${config.home.homeDirectory}/.local/share/wallpapers";
  screenshotDir = "${config.home.homeDirectory}/Pictures/Screenshots";

  # The visualiser is a per-host opt-in, exactly as it was on waybar. cava
  # itself is gone from the picture: waybar had no visualiser, so `custom/cava`
  # was a script feeding it one frame of glyphs per line, where noctalia draws
  # its own from the PipeWire stream. The script and the package stay for the
  # full-size terminal version.
  visualiser = lib.optional config.local.waybar.cavaInBar "audio_visualizer";

  # --- hooks ------------------------------------------------------------
  #
  # Carry changes noctalia made outward to the pieces of the session that do
  # not read its palette directly.

  # Wallpaper -> the login screen.
  #
  # modules/nixos/niri.nix watches ~/.local/state/niri-theme/wallpaper with a
  # systemd path unit and copies whatever it names somewhere the greeter's own
  # user can read, converting it to PNG on the way. Under the waybar stack
  # `wallpaper-set` wrote that file; noctalia owns the wallpaper now and knows
  # nothing about the greeter, so this is the one line that keeps the login
  # screen wearing the same image as the desktop.
  #
  # Written through a temporary file and renamed, because the reader is woken
  # by the write: `PathChanged` fires on close, and a half-written path would
  # be read as a filename that doesn't exist.
  sddmWallpaperSync = pkgs.writeShellApplication {
    name = "noctalia-sddm-wallpaper-sync";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      path="''${NOCTALIA_WALLPAPER_PATH:-}"
      [ -n "$path" ] || exit 0
      [ -f "$path" ] || exit 0

      mkdir -p ${lib.escapeShellArg stateDir}
      tmp="${stateDir}/wallpaper.tmp"
      printf %s "$path" > "$tmp"
      mv -f "$tmp" "${stateDir}/wallpaper"
    '';
  };

  # Noctalia palette -> niri overview backdrop.
  #
  # The builtin niri template already resolves Noctalia's live `surface`
  # colour into ~/.config/niri/noctalia.kdl, but it only themes borders,
  # shadows and hints. The overview backdrop is absent, so it keeps the colour
  # from theming.nix even when Noctalia changes to a builtin, wallpaper, or
  # community palette that has no corresponding theme directory.
  #
  # Run after the templates and read the same manifest SDDM and Limine read.
  # It is rendered directly from Noctalia's colour roles, so this no longer
  # depends on the formatting of the builtin niri template. Replacing the
  # file atomically gives niri one complete config change to live-reload
  # instead of a partially appended KDL block.
  niriOverviewSync = pkgs.writeShellApplication {
    name = "noctalia-niri-overview-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      fragment=${lib.escapeShellArg "${config.xdg.configHome}/niri/noctalia.kdl"}
      [ -f "$fragment" ] || exit 0

      surface="$(sed -n \
        's/^bg=\(#[0-9A-Fa-f]\{6\}\)$/\1/p' \
        ${lib.escapeShellArg resolvedThemeFile} | head -n1 || true)"
      [ -n "$surface" ] || exit 0

      tmp="$(mktemp)"
      trap 'rm -f "$tmp"' EXIT

      sed \
        '/^\/\/ >>> NOCTALIA NIRI OVERVIEW >>>$/,/^\/\/ <<< NOCTALIA NIRI OVERVIEW <<<$/d' \
        "$fragment" > "$tmp"

      printf '%s\n' \
        "" \
        '// >>> NOCTALIA NIRI OVERVIEW >>>' \
        'overview {' \
        "    backdrop-color \"$surface\"" \
        '}' \
        '// <<< NOCTALIA NIRI OVERVIEW <<<' >> "$tmp"

      mv -f "$tmp" "$fragment"
      trap - EXIT
    '';
  };

  # Make the generated Vencord theme active without replacing any other local
  # themes. Vencord and Vesktop use the same settings schema but keep separate
  # data directories. Their theme watcher repaints a running client when the
  # enabled file changes; the first deployment needs one client restart so its
  # in-memory settings pick up the added filename.
  vencordThemeEnable = pkgs.writeShellApplication {
    name = "noctalia-vencord-theme-enable";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      config_home="''${XDG_CONFIG_HOME:-${config.xdg.configHome}}"

      for data_dir in "$config_home/Vencord" "$config_home/vesktop"; do
        settings="$data_dir/settings/settings.json"
        mkdir -p "$(dirname "$settings")"

        if [ -s "$settings" ]; then
          if ! updated="$(jq '
            if type == "object" then . else {} end
            | .enabledThemes = (((.enabledThemes // []) + ["noctalia.theme.css"]) | unique)
          ' "$settings")"; then
            echo "noctalia: not changing invalid Vencord settings: $settings" >&2
            continue
          fi
        else
          updated='{"enabledThemes":["noctalia.theme.css"]}'
        fi

        tmp="$(mktemp "$(dirname "$settings")/.settings.json.XXXXXX")"
        printf '%s\n' "$updated" > "$tmp"
        if [ -f "$settings" ] && cmp -s "$settings" "$tmp"; then
          rm -f "$tmp"
        else
          mv -f "$tmp" "$settings"
        fi
      done
    '';
  };

  # Colour scheme -> everything that is not the shell.
  #
  # The previous version reverse-engineered Kitty, btop and niri output. That
  # made three unrelated builtin templates an accidental API, and one missing
  # or slightly reformatted value prevented the manifest from being written at
  # all. Noctalia now renders the manifest and each app file directly from its
  # colour roles. This post-hook only validates those outputs and publishes the
  # completed live directory.
  #
  # Repointing `active` is the load-bearing half: kdeglobals — and so Dolphin
  # and every other Qt app in the session — plus the local VS Code theme
  # extension follow that symlink. Merely writing `current=noctalia-live`, as
  # an earlier hook did, woke the system path units while leaving those
  # applications on a prebuilt Nix palette.
  themeResync = pkgs.writeShellApplication {
    name = "noctalia-theme-resync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.dbus
      vencordThemeEnable
    ];
    text = ''
      manifest=${lib.escapeShellArg resolvedThemeFile}

      required_outputs=(
        "$manifest"
        ${lib.escapeShellArg "${liveThemeDir}/kdeglobals"}
        ${lib.escapeShellArg "${liveThemeDir}/vscode-extension/package.json"}
        ${lib.escapeShellArg "${liveThemeDir}/vscode-extension/themes/niri-color-theme.json"}
        ${lib.escapeShellArg "${liveThemeDir}/wofi.css"}
        ${lib.escapeShellArg "${liveThemeDir}/wofi-emoji.css"}
        ${lib.escapeShellArg "${spotifyThemeDir}/colors.css"}
        ${lib.escapeShellArg "${config.xdg.configHome}/Vencord/themes/noctalia.theme.css"}
        ${lib.escapeShellArg "${config.xdg.configHome}/vesktop/themes/noctalia.theme.css"}
      )

      for output in "''${required_outputs[@]}"; do
        if [ ! -s "$output" ]; then
          echo "noctalia: refusing to publish an incomplete theme; missing $output" >&2
          exit 1
        fi
      done

      for key in bg bg_alt fg fg_dim accent accent_dim warn err border \
                 color0 color1 color2 color3 color4 color5 color6 color7 \
                 color8 color9 color10 color11 color12 color13 color14 color15; do
        if ! grep -Eq "^$key=#[0-9A-Fa-f]{6}$" "$manifest"; then
          echo "noctalia: invalid or missing '$key' in $manifest" >&2
          exit 1
        fi
      done

      mkdir -p ${lib.escapeShellArg stateDir}
      ln -sfn ${lib.escapeShellArg liveThemeDir} ${lib.escapeShellArg activeThemeDir}
      noctalia-vencord-theme-enable

      # `current` is a sentinel now and nothing more.
      #
      # Nothing selects anything from it: SDDM and Limine read the manifest,
      # Spotify reads the live CSS through its private mount namespace, and
      # none of the three can be described by a palette *name* in the first
      # place. What is left is a
      # marker that says which of the two shells last wrote this directory —
      # which is what keeps the waybar branch of theming.nix's activation from
      # mistaking a noctalia session for a stale prebuilt theme.
      current_tmp="$(mktemp ${lib.escapeShellArg "${stateDir}/current.XXXXXX"})"
      printf '%s\n' noctalia-live > "$current_tmp"
      mv -f "$current_tmp" "${stateDir}/current"

      # KDE's palette-changed broadcast, which is what Plasma itself sends
      # when a colour scheme is applied. Qt clients that listen — anything
      # loading plasma-integration, which is everything in this session —
      # repaint now, and the rest read kdeglobals on their next launch.
      dbus-send --session --type=signal \
        /KGlobalSettings org.kde.KGlobalSettings.notifyChange \
        int32:0 int32:0 >/dev/null 2>&1 || true
    '';
  };

  # --- lock screen ------------------------------------------------------
  #
  # The desktop session panel and lock screen normally read one shared action
  # list. Noctalia only filters `lock` and `lock_and_suspend` while locked, so
  # putting reboot and power-off back in the desktop panel would put them on
  # the lock screen too. There is no per-surface action list in v5.
  #
  # Keep the desktop panel complete, hide the login box's shared action row,
  # and draw two lockscreen button widgets instead: Suspend and Switch user.
  # The login box, those buttons, and the clock are positioned from the mode
  # already declared in `local.niri.outputs`; a monitor change therefore moves
  # the whole composition rather than leaving fixed coordinates behind.
  #
  # **Battery is not here, and cannot be.** noctalia has no battery widget for
  # the lock screen or the desktop — the widget types are clock, label,
  # button, sysmon, media_player, weather, sticker, volume, the two
  # visualisers and login_box, and sysmon's stats are CPU, GPU, RAM, swap and
  # network with nothing for the power supply. There is no official plugin for
  # it either. The charge remains on the bar and in the control centre.

  # "2560x1440@180.000" -> { w = 2560; h = 1440; }, null if it doesn't parse.
  parseMode =
    mode:
    let
      m = builtins.match "([0-9]+)x([0-9]+)(@.*)?" mode;
    in
    if m == null then
      null
    else
      {
        w = lib.toInt (builtins.elemAt m 0);
        h = lib.toInt (builtins.elemAt m 1);
      };

  # Outputs that get a clock. `local.niri.outputs` is the good case — it
  # carries the mode, so the clock lands in the middle of the display. A host
  # that leaves the layout to niri's auto-detection (the laptop) has no modes
  # to read, so `local.niri.lockClockOutputs` names the connectors and the
  # position falls back to a 1080p centre, which clamping then pulls onto
  # whatever the panel actually is.
  lockOutputs =
    if config.local.niri.lockClockOutputs != [ ] then
      map (name: {
        inherit name;
        mode = null;
        scale = null;
        off = false;
      }) config.local.niri.lockClockOutputs
    else
      map (o: {
        inherit (o) name mode off;
        scale = o.scale;
      }) config.local.niri.outputs;

  # One full-output audio visualizer, a compact login box, an auto-hiding media
  # player, two lock-safe buttons, and two clock widgets per output.
  #
  # A clock widget has one font size, so "time bigger than the date" cannot be
  # done inside a single `format` string — it needs two widgets sized
  # independently. And the *only* size control noctalia exposes for a lock
  # screen widget is the box: with both `box_width` and `box_height` set the
  # widget scales its content to fill them, aspect-preserved
  # (`contentScaleForBox`), and the clock's font is
  # `fontSizeBody * 4 * contentScale`. There is no `font_size` setting, and no
  # `scale` key on a widget in this version. So the boxes below *are* the type
  # scale, and they are fractions of the output rather than fixed pixels so
  # the proportions hold on a 1080p panel and a 1440p one alike.
  #
  # The clock pair sits above the login box. The two buttons sit below it and
  # replace the shared session-action row that is disabled on the login box.
  lockWidgets = lib.listToAttrs (
    lib.concatMap (
      o:
      let
        parsed = if o.mode == null then null else parseMode o.mode;
        scale = if o.scale == null then 1 else o.scale;

        # Logical pixels, which is the space widgets are positioned in — a
        # scaled output occupies mode / scale, the same arithmetic the
        # `position` fields in local.niri.outputs are written in.
        w = builtins.floor ((if parsed == null then 1920 else parsed.w) / (scale + 0.0));
        h = builtins.floor ((if parsed == null then 1080 else parsed.h) / (scale + 0.0));

        timeW = builtins.floor (w * 0.30);
        timeH = builtins.floor (h * 0.13);
        dateW = builtins.floor (w * 0.22);
        dateH = builtins.floor (h * 0.045);

        cx = w / 2;
        timeCy = builtins.floor (h * 0.26);

        # The native compact layout is one control-height row plus padding.
        # Keep its upstream 400px width cap.
        loginW = lib.min 400 (w - 48);
        loginH = 72;
        loginCy = h - 84 - (loginH / 2);

        # The login box draws a prompt line — "Please enter your password" —
        # *above* the row it declares, so that text is outside `loginH` and
        # the box's own geometry says nothing about it. Media sitting a plain
        # gap above `loginCy - loginH/2` therefore landed on top of the
        # prompt. This clears the prompt's line box (body text plus its
        # leading) and then leaves the same visual gap above it, which is what
        # puts the player above the message rather than across it.
        promptClearance = 30;

        # Narrower than the login box below it rather than the same width.
        # Two stacked panels of equal width read as one broken-up slab; the
        # player being visibly inset makes the login box the thing the eye
        # lands on, which is the one that wants attention.
        mediaW = lib.min 320 (w - 48);
        mediaH = 132;
        mediaCy = loginCy - (loginH / 2) - promptClearance - 32 - (mediaH / 2);

        buttonW = 170;
        buttonH = 42;
        buttonGap = 12;
        buttonOffset = (buttonW + buttonGap) / 2;
        buttonCy = h - 42;

        # Baselines touch rather than overlap: half of each box plus a small
        # gap. Derived from the boxes above so changing the type scale moves
        # the date with it instead of leaving a hole.
        dateCy = timeCy + builtins.floor (timeH * 0.5) + builtins.floor (dateH * 0.5) + builtins.floor (h * 0.012);

        common = {
          type = "clock";
          output = o.name;

          settings = {
            clock_style = "digital";
            center_text = true;

            # Poppins for both. It is a geometric sans with a tall x-height,
            # which is what makes a very large time read as deliberate rather
            # than as the UI font blown up — and the shell's own
            # FiraCode Nerd Font is a monospace, which at this size looks like
            # a terminal rather than a clock.
            font_family = "Poppins";

            # No panel behind either. A slab of surface colour under a clock
            # on top of a wallpaper is the least elegant thing the widget can
            # do, and it is also the expensive one — it drops a rounded rect
            # and an alpha layer per widget per output per frame.
            background = false;

            # Which makes the text shadow load-bearing rather than
            # decorative: with no panel behind it, it is the only thing
            # keeping the time legible over a pale wallpaper.
            shadow = false;
          };
        };

        lockButton = {
          type = "button";
          output = o.name;
          cy = buttonCy;
          box_width = buttonW;
          box_height = buttonH;

          settings = {
            background = true;
            font_family = "Poppins";
            variant = "secondary";
          };
        };
      in
      [
        # First in widget_order below, so it paints behind every other custom
        # lock-screen widget. The login panel is a later root layer too. With
        # no background or padding the spectrum fills the entire logical
        # output, and show_when_idle=false fades it away when playback stops.
        (lib.nameValuePair "audio_visualizer_${o.name}" {
          type = "audio_visualizer";
          output = o.name;
          cx = cx;
          cy = h / 2;
          box_width = w;
          box_height = h;

          settings = {
            bands = 64;
            mirrored = true;
            centered = false;
            show_when_idle = false;
            color_1 = "primary";
            color_2 = "secondary";
            background = false;
            background_padding = 0;
          };
        })
        (lib.nameValuePair "login_box_${o.name}" {
          type = "login_box";
          output = o.name;
          cx = cx;
          cy = loginCy;
          box_width = loginW;
          box_height = loginH;

          settings = {
            layout = "compact";
            show_session_buttons = false;
            show_weather = false;
            show_media = false;
          };
        })
        (lib.nameValuePair "media_player_${o.name}" {
          type = "media_player";
          output = o.name;
          cx = cx;
          cy = mediaCy;
          box_width = mediaW;
          box_height = mediaH;

          settings = {
            vertical = false;
            hide_when_no_media = true;
            background = true;
            background_opacity = 0.82;
            background_radius = 16;
            background_padding = 10;
            shadow = true;
          };
        })
        (lib.nameValuePair "clock_time_${o.name}" (
          lib.recursiveUpdate common {
            cx = cx;
            cy = timeCy;
            box_width = timeW;
            box_height = timeH;
            settings.format = "{:%-I:%M %p}";
          }
        ))
        (lib.nameValuePair "clock_date_${o.name}" (
          lib.recursiveUpdate common {
            cx = cx;
            cy = dateCy;
            box_width = dateW;
            box_height = dateH;
            settings.format = "{:%A, %B %-d}";
          }
        ))
        (lib.nameValuePair "lock_suspend_${o.name}" (
          lib.recursiveUpdate lockButton {
            cx = cx - buttonOffset;
            settings = {
              glyph = "moon";
              label = "Suspend";
              command = "${pkgs.systemd}/bin/systemctl suspend";
            };
          }
        ))
        (lib.nameValuePair "lock_switch_user_${o.name}" (
          lib.recursiveUpdate lockButton {
            cx = cx + buttonOffset;
            settings = {
              glyph = "users";
              label = "Switch user";
              command = lib.getExe niriScripts.switchUser;
            };
          }
        ))
      ]
    ) (lib.filter (o: !o.off) lockOutputs)
  );

  # This is paint order as well as editor order: the lock-screen host appends
  # widget scene nodes in this sequence. Keep the full-screen visualizer first
  # and list every widget, because an explicit order is authoritative.
  lockWidgetOrder = lib.concatMap (o: [
    "audio_visualizer_${o.name}"
    "clock_time_${o.name}"
    "clock_date_${o.name}"
    "media_player_${o.name}"
    "lock_suspend_${o.name}"
    "lock_switch_user_${o.name}"
    "login_box_${o.name}"
  ]) (lib.filter (o: !o.off) lockOutputs);

  settings = {
    shell = {
      # The bar's font under waybar, kept so the glyphs in the widget labels
      # have the same metrics they did. noctalia has one font family for all
      # shell text and no separate mono field.
      font_family = "FiraCode Nerd Font";

      time_format = "{:%I:%M %p}";
      date_format = "%a, %b %d";

      # A polkit agent already runs in this session — modules/nixos/niri.nix
      # starts polkit-kde-agent as a user service, because the disk tools in
      # modules/nixos/disk-managements.nix need one. Two agents racing for the
      # same authority is the failure this avoids.
      polkit_agent = false;

      # Clipboard history, replacing cliphist. 300 entries is the cap the
      # cliphist unit carried, chosen there because images are stored too and
      # an entry can cost a screenshot's worth of disk rather than a line's.
      clipboard_enabled = true;
      clipboard_history_max_entries = 300;

      niri_overview_type_to_launch_enabled = true;
      settings_show_advanced = true;

      privacy = {
        # cava opens a PipeWire source to read the *output* stream, which is
        # not a microphone in use — without this the privacy indicator sits
        # lit whenever the visualiser is running. Same exclusion the old
        # `waybar-microphone-privacy` helper made in jq (see ./privacy.nix),
        # now one setting.
        mic_filter_regex = "cava";
      };

      launcher = {
        categories = true;
        show_icons = true;
        sort_by_usage = true;

        # No currency rates. This config pins its inputs and the shell should
        # not reach out to a third-party API on its own; the calculator
        # provider still does arithmetic offline.
        fetch_exchange_rates = false;
      };

      screenshot = {
        directory = screenshotDir;

        # satty for annotation, which is the whole reason region capture was a
        # script rather than a niri action. `-f -` reads the image on stdin.
        pipe_command = "${pkgs.satty}/bin/satty -f -";
        copy_to_clipboard = true;
      };

      # --- where the panels open ----------------------------------------
      #
      # Attached rather than floating: a panel that hangs off the bar reads as
      # belonging to the widget that opened it, where a floating one appears
      # in the middle of the screen with nothing connecting the two.
      #
      # `open_near_click_*` is what puts them on the *right*. Attached panels
      # are otherwise centred on the bar, so the control centre — whose widget
      # is at the far right end — opened in the middle of the screen and had
      # to be tracked back to the icon that produced it. With this they drop
      # directly under what was clicked, which for everything in the
      # right-hand cluster means the right-hand side.
      #
      # The launcher is deliberately not in that list. It is a search box
      # rather than a menu belonging to a widget, it is opened from the
      # keyboard as often as from the bar, and centred is where a search box
      # is expected.
      panel = {
        transparency_mode = "soft";
        borders = true;
        shadow = true;

        launcher_placement = "floating";
        launcher_position = "center";

        control_center_placement = "attached";
        session_placement = "attached";
        wallpaper_placement = "attached";
        clipboard_placement = "attached";

        open_near_click_control_center = true;
        open_near_click_session = true;
        open_near_click_wallpaper = true;
        open_near_click_clipboard = true;
      };

      # --- what the desktop session panel offers --------------------------
      #
      # Noctalia has one shared action list, but the lock screen only needs
      # Suspend and Switch user. Its shared row is disabled above and replaced
      # with those two explicit lockscreen widgets, leaving this desktop list
      # free to carry the complete set of requested actions.
      #
      # **Switch user is a `command`.** The action vocabulary is lock,
      # logout, suspend, lock_and_suspend, reboot, shutdown and command —
      # there is no switch-user verb, because switching users is a greeter
      # operation rather than a session one. `switch-user` from ./scripts.nix
      # is the script that already knows how to do it (it asks logind for a
      # greeter on a spare VT and leaves this session running), which is the
      # same one the waybar session menu called.
      session.show_shortcuts = true;
      session.actions = [
        {
          action = "lock";
          label = "Lock";
          shortcut = "1";
        }
        {
          action = "lock_and_suspend";
          label = "Lock and suspend";
          shortcut = "2";
        }
        {
          action = "command";
          label = "Switch user";
          glyph = "users";
          command = lib.getExe niriScripts.switchUser;
          shortcut = "3";
        }
        {
          action = "logout";
          label = "Log out";
          shortcut = "4";
        }
        {
          action = "reboot";
          label = "Reboot";
          shortcut = "5";
        }
        {
          action = "shutdown";
          label = "Power off";
          variant = "destructive";
          shortcut = "6";
        }
      ];
    };

    # --- bar ------------------------------------------------------------
    #
    # The waybar layout, slot for slot. Its geometry came from
    # `programs.waybar.settings.main` and its look from the generated
    # stylesheet; both are settings here because noctalia has no stylesheet.
    #
    #   height 34        -> thickness
    #   margin-top 6     -> margin_edge
    #   margin-left 10   -> margin_ends
    #   border-radius 12 -> radius
    #   alpha(@bg, 0.88) -> background_opacity
    #
    # `widget_spacing` and `padding` are the two that deliberately do *not*
    # match waybar. waybar's 4px gap was chosen to claw back room from a
    # twelve-slot right-hand cluster that had grown too wide; that cluster is
    # four slots shorter now, so the gap can go back to something that reads
    # as separate controls rather than one run-on strip.
    bar.main = {
      position = "top";
      thickness = 34;
      widget_spacing = 8;
      padding = 16;
      margin_edge = 6;
      margin_ends = 10;
      radius = 12;
      background_opacity = 0.88;
      shadow = true;
      reserve_space = true;

      start = [
        "launcher_button"
        "workspaces"
        "active_window"
      ];

      center = [ "clock" ];

      # Right-hand cluster, in waybar's order, minus four that were doing a
      # job something else already does:
      #
      #   lock       the session panel next door offers it, and Mod+L is the
      #              reflex anyway
      #   clipboard  Mod+Ctrl+V, and the launcher's own clipboard provider
      #   lock_keys  the caps-lock OSD says it louder, and this only ever had
      #              anything to show while a key was actually held on
      #
      # What stays is either a live reading (brightness, volume, network,
      # bluetooth, battery) or an indicator that means
      # something by being present at all (privacy, notifications).
      end =
	visualiser
        ++ [
          "media"
          "tray"
          "notifications"
          "brightness"
          "volume"
          "bluetooth"
          "network"
          "privacy"
          "joshr/gamemode-indicator:status"

          # Caffeine takes the slot that previously showed the power profile.
          # Keep it and the battery as ordinary bar widgets: a capsule group
          # paints its own background, which made Caffeine look unlike the
          # buttons around it.
          "battery"
          "caffeine"

          "wallpaper"
          "control-center"
          "session"
        ];
    };

    widget = {
      # --- the left cluster -------------------------------------------------
      #
      # One icon, one row of pills, one line of text, in that order, and each
      # doing a different job. What it used to be was three text-bearing
      # objects of three different weights sitting next to each other — a
      # glyph with "joshr" beside it, pills scaled up 25% past everything else
      # on the bar, and a window title with a placeholder standing in for it
      # whenever nothing was focused. Elegance here is mostly subtraction:
      # every one of the changes below removes something that was on screen
      # permanently while saying nothing that changed.

      # The launcher, first thing on the bar, as the NixOS snowflake.
      #
      # This slot has been through three shapes. Under waybar it was
      # `custom/user`: static text with no `exec` and no action, printing the
      # username. It became a glyph that opens the launcher — which is the
      # entry point wofi never had a bar slot for at all — and the username
      # moved to the tooltip. Now it says what it *does* rather than who it
      # belongs to, which is the only one of the three that a stranger could
      # read correctly.
      #
      # `custom_image` overrides `glyph`, and `custom_image_colorize` is what
      # keeps it from being the one thing on the bar that ignores the palette:
      # the snowflake is drawn as a flat accent-coloured mark, the same weight
      # as the glyphs in the right-hand cluster, and it follows a colour-scheme
      # change with everything else. Set `custom_image_colorize = false` for
      # the artwork's own two blues instead.
      #
      # `nixos-icons` is the NixOS artwork repository packaged in Freedesktop
      # icon layout; the scalable copy is the same shape of file as every
      # application icon the launcher itself resolves.
      launcher_button = {
        type = "custom_button";
        custom_image = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        custom_image_colorize = true;
        tooltip = "Applications — ${config.home.username}";
        command = "noctalia msg panel-toggle launcher";
      };

      workspaces = {
        # 1.25 made the pills the tallest thing on a 34px bar and left them
        # visibly out of scale with the tray and the buttons either side.
        # 1.1 still reads at a glance without becoming the loudest element in
        # the session.
        scale = 1.1;

        # Numbers only where a number is worth having.
        #
        # niri creates and destroys workspaces as you use them, so the last
        # one in the row is always the empty one waiting to be moved into.
        # Numbering it is numbering a placeholder. With this, an occupied
        # workspace is a labelled pill and an empty one is a plain dot, which
        # says the same thing with less ink and makes "where are my windows"
        # answerable without reading.
        labels_only_when_occupied = true;
      };

      clock = {
        format = "{:%I:%M %p   %a, %b %d}";
        tooltip_format = "{:%A, %B %d, %Y}";
      };

      active_window = {
        display = "icon_and_text";
        max_length = 300;

        # Shrink to the title rather than reserving a slot for one.
        #
        # The default is 80px of floor, which on a short title leaves a gap
        # between the workspaces and the centred clock that reads as something
        # failing to render. At 0 the cluster is exactly as wide as what is in
        # it.
        min_length = 0;

        # And draw nothing at all when nothing is focused, instead of a
        # placeholder label. Together with `min_length` the widget disappears
        # cleanly on an empty workspace.
        show_empty_label = false;

        # A truncated title is a title you cannot read. Scrolling it under the
        # pointer costs nothing while the mouse is elsewhere — which is the
        # whole time — and means `max_length` is a layout choice rather than
        # an information limit.
        title_scroll = "on_hover";

        # The app icon at 16px against the 13px body text: enough that the
        # icon leads and the title follows, which is the reading order the
        # `icon_and_text` display implies.
        icon_size = 16;
      };

      # Now playing.
      #
      # `max_length` is a width in pixels, capped at 800 by the widget itself,
      # and the same unit `active_window` above uses — not a count of glyphs.
      # At 200 it was cutting "Artist · Title" down to about the artist. The
      # bar's right-hand cluster lost four slots in the move off waybar, so
      # there is room to let this run on, and `hide_when_no_media` means it
      # costs that width only while something is playing.
      #
      # `title_scroll` is the other half of the answer and the more useful
      # one: no fixed width fits every track, so anything past 270px scrolls
      # continuously rather than being lost to an ellipsis. Scroll gestures
      # replace the built-in track skipping with 5% changes to the active
      # MPRIS player's own volume.
      media = {
        max_length = 270;
        min_length = 0;
        title_scroll = "always";
        hide_when_no_media = true;
        # actions = {
        #   scroll_up = "media volume-up";
        #   scroll_down = "media volume-down";
        # };
      };

      network = {
        show_label = true;
      };

      # Camera, microphone and screen-share indicators, and only while one of
      # them is actually open.
      #
      # This is the behaviour waybar's pair of modules had and lost in the
      # move: `custom/microphone-privacy` printed an empty line when nothing
      # held the mic, and waybar hides a custom module with no text, so the
      # slot cost nothing the rest of the time. noctalia draws all three
      # glyphs greyed out by default, which is three permanent icons saying
      # "not recording" — the state you are in essentially always.
      privacy = {
        hide_inactive = true;
      };
    };

    # --- colour -----------------------------------------------------------
    #
    # `custom` rather than `builtin` or `wallpaper`: the palettes are the ones
    # in themes.nix, written out by ./noctalia-palettes.nix.
    #
    # `mode = "dark"` is not really a mode here. Each theme in themes.nix is a
    # finished palette that is already light or dark — gruvbox-light is the
    # light one — so both variants of each generated palette hold the same
    # colours and this only picks which of two identical halves gets read.
    theme = {
      mode = "dark";
      source = "custom";
      custom_palette = paletteSet.default;

      # --- and how it reaches everything that is not the shell -------------
      #
      # Noctalia is now the source of the live system palette, not merely the
      # shell consumer of a finite Nix theme. Its user templates write one
      # complete live directory plus the files consumed directly by Spotify
      # and Vencord. The final manifest template publishes that directory and
      # wakes SDDM and Limine. This works unchanged for custom, builtin,
      # wallpaper-derived and community palettes because the templates see
      # resolved colour roles rather than a palette name.
      #
      # The builtin kcolorscheme remains off. Its post-action writes
      # ~/.config/kdeglobals itself, while ./default.nix deliberately owns that
      # path as a symlink. The user template below instead writes the target
      # inside `noctalia-live`; repointing `active` switches KDE, Dolphin and
      # VS Code together without two writers fighting over kdeglobals.
      #
      # Every builtin template renders the palette into a *side* file the app
      # can include — `kitty/themes/noctalia.conf`, `btop/themes/noctalia.theme`
      # — and then runs a hook that makes the app read it. It is the hook, not
      # the render, that is awkward on NixOS: it edits the app's main config,
      # which home-manager owns here as a read-only symlink into the store.
      #
      # Every one of those hooks is idempotent, though — each checks for its
      # own line before writing anything. So the way to make them work is to
      # declare that line on the home-manager side and let the hook find its
      # job already done. That is what the `programs.*` settings and the
      # `xdg.configFile` entries in the config block below are for, and each
      # is commented with the hook it is satisfying. The store file stays
      # declarative, the hook stays a no-op, and neither has to know about the
      # other.
      #
      #   kitty      `include themes/noctalia.conf`, via programs.kitty.extraConfig
      #   btop       `color_theme = "noctalia"`, via programs.btop.settings
      #   cava       `[color] theme = "noctalia"`, via xdg.configFile
      #   niri       `include "noctalia.kdl"`, written into config.kdl by niri.nix
      #   gtk3/gtk4  nothing — gtk.css is not managed here, and their hook
      #              already replaces a read-only symlink with a real file
      #   qt         nothing — plain side files for qt5ct/qt6ct, no hook
      #   alacritty  nothing — alacritty is not installed and its config is
      #              not managed, so the hook creates the file it wants
      #   starship   the exception: see the starship block in the config
      #              below. Its hook has to inject the palette *into*
      #              starship.toml, so there is no line to pre-declare
      templates = {
        enable_builtin_templates = true;
        builtin_ids = [
          "alacritty"
          "btop"
          "cava"
          "gtk3"
          "gtk4"
          "kitty"
          "niri"
          "qt"
          # "starship"
        ];

        # --- community templates ------------------------------------------
        #
        # noctalia-dev/community-templates, fetched from api.noctalia.dev on
        # first use and cached under ~/.cache/noctalia. That is a runtime
        # fetch, which is against the grain of a config that pins every input
        # in flake.lock — the tradeoff is taken deliberately, because these
        # are the apps whose theming would otherwise have to be reimplemented
        # here one renderer at a time, and upstream maintains them against
        # each app's actual config format.
        #
        # What it means in practice: the templates apply from the second run
        # onwards on a machine with no network, and a template whose upstream
        # entry changes shape changes what lands in `~/.config` without a
        # rebuild. Nothing in the *session* depends on them — the shell, the
        # terminal, GTK, Qt and the greeter are all builtin or user templates
        # above — so a failed fetch costs these apps their colours and
        # nothing else.
        #
        # `community_ids` takes catalog ids (the directory names in that
        # repository), not the individual `[templates.*]` entry names:
        # `vscode` covers Code, Codium and Antigravity.
        #
        #   blender        renders a theme script and runs it headless;
        #                  gated on ~/.config/blender existing
        #   discord        Vencord/Vesktop/BetterDiscord variants. Extra
        #                  selectable themes beside the `vencord` user
        #                  template below, which stays the enabled one
        #   fastfetch      merges colours into ~/.config/fastfetch/config.jsonc,
        #                  which has to exist and be strict JSON — see the
        #                  seed in the activation block
        #   inkscape       ui/user.css; gated on ~/.config/inkscape existing
        #   obs            the Matugen .obt theme, which ../obs.nix selects
        #   papirus-icons  recolours the folder icons in place, which needs a
        #                  writable copy of the icon theme — see the seed below
        #   prismlauncher  a "Matugen" theme under its data directory
        #   vscode         a NoctaliaTheme extension; ../vscode.nix ships the
        #                  manifest the rendered theme file belongs to
        #   zellij         a theme file; needs `theme "noctalia"` in zellij's
        #                  own config, which is not managed here
        #   zen-browser    userChrome/userContent, applied into every Zen
        #                  profile it finds. A no-op with Zen not installed
        enable_community_templates = true;
        community_ids = [
          "blender"
          "discord"
          "fastfetch"
          "inkscape"
          "obs"
          "papirus-icons"
          "prismlauncher"
          "vscode"
          "zellij"
          "zen-browser"
        ];

        # These are local user templates, so Noctalia itself resolves every
        # palette source and writes all downstream formats. Indices make the
        # state manifest last: its post-hook can only publish a complete set.
        user = {
          kde = {
            input_path = "${config.xdg.configHome}/noctalia/templates/kdeglobals";
            output_path = "${liveThemeDir}/kdeglobals";
            index = 100;
          };
          vscode_package = {
            input_path = "${config.xdg.configHome}/noctalia/templates/vscode-package.json";
            output_path = "${liveThemeDir}/vscode-extension/package.json";
            index = 110;
          };
          vscode = {
            input_path = "${config.xdg.configHome}/noctalia/templates/vscode.json";
            output_path = "${liveThemeDir}/vscode-extension/themes/niri-color-theme.json";
            index = 120;
          };
          # wofi is not the launcher any more, but `theme-menu`,
          # `wallpaper-menu` and `session-menu` in ./scripts.nix all still
          # drive it as a plain `--dmenu`, and ./emoji.nix passes it a second
          # stylesheet with bigger rows. Both are named under `active` by
          # those modules, which under this shell is the live directory — so
          # without these two the menus would come up in wofi's own default
          # look while everything around them followed the palette.
          wofi = {
            input_path = "${config.xdg.configHome}/noctalia/templates/wofi.css";
            output_path = "${liveThemeDir}/wofi.css";
            index = 125;
          };
          wofi_emoji = {
            input_path = "${config.xdg.configHome}/noctalia/templates/wofi-emoji.css";
            output_path = "${liveThemeDir}/wofi-emoji.css";
            index = 126;
          };
          spotify = {
            input_path = "${config.xdg.configHome}/noctalia/templates/spotify.css";
            output_path = "${spotifyThemeDir}/colors.css";
            index = 130;
          };
          vencord = {
            input_path = "${config.xdg.configHome}/noctalia/templates/vencord.css";
            output_path = [
              "${config.xdg.configHome}/Vencord/themes/noctalia.theme.css"
              "${config.xdg.configHome}/vesktop/themes/noctalia.theme.css"
            ];
            index = 140;
          };
          system_palette = {
            input_path = "${config.xdg.configHome}/noctalia/templates/system-palette.conf";
            output_path = resolvedThemeFile;
            post_hook = "${lib.getExe themeResync} && ${lib.getExe niriOverviewSync}";
            index = 900;
          };
        };
      };
    };

    # --- wallpaper --------------------------------------------------------
    #
    # Replaces awww and the `wallpaper-set` / `wallpaper-random` /
    # `wallpaper-restore` trio in ./scripts.nix. noctalia remembers the
    # selection itself, so the `spawn-at-startup` that restored it at login has
    # nothing left to do.
    wallpaper = {
      enabled = true;

      # ~/.local/share/wallpapers — the tree home/joshr/home.nix links the
      # dotfiles' images into and home/joshr/wallhaven.nix drops the locked
      # top 20 into, under WallhavenFlake/.
      directory = wallpaperDir;

      fill_mode = "crop";
      transition = [ "disc" ];
      transition_duration = 1500;
      transition_on_startup = true;

      # Recursive, and this is what makes the wallhaven set pickable rather
      # than only shufflable: the same flag drives the picker's scan and the
      # automation's random draw, so without it the panel would list the
      # handful of images sitting directly in the directory and none of the
      # twenty in WallhavenFlake/.
      automation.recursive = true;

      default.path = "${wallpaperDir}/nixos.png";
    };

    # --- notifications ----------------------------------------------------
    #
    # dunst's placement, kept: top-right with a 16px margin. The urgency
    # timeouts dunst carried (5s low, 8s normal, never for critical) are
    # noctalia's own behaviour and have no setting.
    notification = {
      enable_daemon = true;
      show_app_name = true;
      show_actions = true;
      offset_x = 16;
      offset_y = 16;
    };

    # --- OSD --------------------------------------------------------------
    #
    # swayosd, whose whole reason for existing was that niri has no OSD and a
    # volume or brightness key was otherwise silent. Placed where swayosd put
    # it: low and centred, clear of the bar at the top.
    osd = {
      position = "bottom_center";
      background_opacity = 0.97;
      offset_x = 20;
      offset_y = 8;

      kinds = {
        volume = true;
        brightness = true;

        # Which is what lets `lock_keys` come off the bar: the caps-lock state
        # is worth a pop-up at the moment it changes and worth nothing as a
        # permanent slot.
        lock_keys = true;
        privacy = true;
      };
    };

    # --- brightness -------------------------------------------------------
    #
    # ddcutil is **on**, and the earlier reasoning for leaving it off was
    # wrong in a way worth writing down.
    #
    # modules/nixos/ddcci.nix loads ddcci-backlight, which speaks DDC/CI in
    # the kernel and registers each external monitor as an ordinary
    # /sys/class/backlight/ddcci* device. The argument was that noctalia would
    # then reach the desk's monitors through sysfs exactly as it reaches a
    # laptop panel, with no second DDC/CI implementation involved. It does not:
    # `enumerateBacklights` only keeps a backlight it can tie to a live
    # Wayland output, and it does that by canonicalising <device> and checking
    # it sits under /sys/class/drm/card*-<CONNECTOR>. A ddcci backlight hangs
    # off its i2c adapter instead, so it matches nothing — and the one
    # fallback in that code path is hardcoded to connectors starting `eDP`.
    #
    # So the laptop's internal panel works through sysfs and every external
    # monitor is silently dropped, which is a brightness widget that does
    # nothing on the desk. `enable_ddcutil` is the supported route for those:
    # noctalia shells out to `ddcutil detect` and drives them from userspace.
    #
    # Two things it needs, both already true here. `hardware.i2c` — enabled by
    # ddcci.nix — loads i2c-dev and puts a uaccess tag on /dev/i2c-*, so this
    # runs as the user rather than needing root. And `ddcutil` has to be on
    # PATH: nixpkgs' noctalia wrapper only prefixes gitMinimal, and the code
    # gates the whole backend on `commandExists("ddcutil")`, so it is added to
    # home.packages below.
    #
    # Noctalia is the only writer under this shell. The old 240-second idle
    # action called the legacy `brightness` helper through ddcci-backlight,
    # racing this ddcutil backend to the same monitor register. It is gone;
    # Noctalia's own pre-action overlay supplies the idle darkening below.
    brightness.enable_ddcutil = true;

    # --- weather ----------------------------------------------------------
    #
    # `auto_locate` resolves coordinates from the machine's public IP rather
    # than from a place name, which is the "automatically" part: nothing to
    # write down, and it follows a laptop that moves.
    #
    # It is worth being explicit that this is the one thing in this config
    # that talks to the network on its own. Weather comes from Open-Meteo and
    # the coordinates come from an IP lookup, so leaving this on means the
    # shell makes an outbound request on a schedule. `[location]` is also what
    # `theme.mode = "auto"` and the night light would use for sunrise/sunset,
    # neither of which is on here.
    weather = {
      enabled = true;
      unit = "fahrenheit";
      refresh_minutes = 30;
    };

    location.auto_locate = true;

    # --- idle -------------------------------------------------------------
    #
    # Noctalia owns this pipeline outright: its fullscreen pre-action overlay
    # darkens the outputs before the native lock and screen-off actions. There
    # is deliberately no separate brightness command and therefore no second
    # DDC/CI writer to save and restore a physical level.
    idle = {
      pre_action_fade_seconds = 2;
      behavior = {
        lock = {
          enabled = true;
          timeout = 300;
          action = "lock";
        };

        screen-off = {
          enabled = true;
          timeout = 600;
          action = "screen_off";
        };
      };
    };

    # --- lock screen ------------------------------------------------------
    #
    # `blurred_desktop = false` is the performance-conscious half of this. The
    # alternative takes a wlr-screencopy snapshot of every output at the moment
    # of locking and blurs that; using the wallpaper skips the capture entirely
    # and blurs an image that is already resident on the GPU. It also survives
    # locking from a blanked screen, where there is nothing to snapshot.
    lockscreen = {
      enabled = true;
      blurred_desktop = false;
      blur_intensity = 0.5;
      tint_intensity = 0.3;
    };

    lockscreen_widgets = {
      enabled = lockWidgets != { };
      widget = lockWidgets;
      widget_order = lockWidgetOrder;
    };

    # --- hooks ------------------------------------------------------------
    hooks = {
      started = [
        (lib.getExe themeResync)
        (lib.getExe niriOverviewSync)
      ];
      wallpaper_changed = lib.getExe sddmWallpaperSync;
      colors_changed = [
        (lib.getExe themeResync)
        (lib.getExe niriOverviewSync)
      ];
    };

    # Sampling for the control centre's system tab. Nothing here is on the
    # bar, so the cost is only paid while the panel is open.
    system.monitor.enabled = true;
  };

  configFile = tomlFormat.generate "noctalia-config.toml" settings;

  # Checked at build time rather than discovered at login.
  #
  # `noctalia config validate` is the shell's own schema check, and running it
  # here is what turns a key that has been renamed upstream into a build
  # failure naming the line, instead of a setting that silently stops applying.
  # It is cheap — the binary comes from the binary cache, and this only reads a
  # file.
  validatedConfig = pkgs.runCommand "noctalia-config.toml" { } ''
    ${noctalia} config validate ${configFile}
    cp ${configFile} $out
  '';

  # Move aside a state file written by a *newer* noctalia than the one now
  # installed.
  #
  # config.toml is generated above and Nix owns it. ~/.local/state/noctalia/
  # settings.toml is the other half: noctalia's own overrides file, holding
  # whatever has been changed from the Settings window, and it is written by
  # the shell rather than by this config. It carries a `config_version`, and
  # noctalia refuses to start on one it does not understand —
  #
  #     config version 12 is newer than supported version 8
  #
  # — which is a *downgrade* symptom, not an upgrade one. Going forwards is
  # handled: there is a migration per version and they run on load. Going
  # backwards has nothing to run, so the shell stops.
  #
  # It is reachable from here because the package moved. An earlier revision
  # of this config took noctalia from its own flake, where `main` is 5.0.0 and
  # writes config_version 12; nixpkgs is on the 5.0.0-beta.7 tag, which knows
  # up to 8. Anyone who ran the flake build once has a state file the packaged
  # build cannot read, on every host they ran it on.
  #
  # **No version number is written down here, on purpose.** The check asks the
  # installed binary instead, with two probes: an empty config, which must
  # pass, and the same thing carrying the version the state file claims. Only
  # when the first passes and the second fails is the version the reason —
  # which keeps this from throwing the file away over some unrelated
  # validation failure, and keeps it correct when nixpkgs moves to a build
  # that does understand 12.
  #
  # Renamed rather than deleted. The overrides are small and mostly duplicate
  # what `settings` above already declares, but they are the user's, and a
  # config that silently deletes state is worse than one that leaves a file
  # to look at.
  reconcileOverrides = ''
    stateFile="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"

    if [ -f "$stateFile" ]; then
      claimed="$(${pkgs.gnused}/bin/sed -n \
        's/^[[:space:]]*config_version[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
        "$stateFile" | ${pkgs.coreutils}/bin/head -n1)"

      if [ -n "$claimed" ]; then
        probeDir="$(${pkgs.coreutils}/bin/mktemp -d)"
        : > "$probeDir/empty.toml"
        printf 'config_version = %s\n' "$claimed" > "$probeDir/claimed.toml"

        if ${noctalia} config validate "$probeDir/empty.toml" >/dev/null 2>&1 \
          && ! ${noctalia} config validate "$probeDir/claimed.toml" >/dev/null 2>&1; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv -f "$stateFile" "$stateFile.too-new"
          echo "noctalia: ~/.local/state/noctalia/settings.toml claims config_version $claimed," >&2
          echo "noctalia: which this build does not support. Moved to settings.toml.too-new." >&2
        fi

        ${pkgs.coreutils}/bin/rm -rf "$probeDir"
      fi
    fi

    # --- and drop the widget placements it persists ------------------------
    #
    # The overrides file is read *after* config.toml and wins, which is right
    # for something the user changed in the Settings window and wrong for the
    # two sections below, because noctalia writes those itself without being
    # asked. `setLockscreenWidgetsState` / `setDesktopWidgetsState` serialise
    # the whole placement — every widget *and* a `widget_order` — and the
    # shell seeds a login box into it on its own.
    #
    # `widget_order` is what makes this a silent override rather than a merge:
    # the reader treats an order list as the definitive membership list, so a
    # stale one naming `clock_DP-3` drops the login box, lock buttons,
    # `clock_time_DP-3`, and `clock_date_DP-3` declared here entirely. The
    # complete lockscreen composition would then look like it did nothing.
    #
    # Only these two sections. Everything else in that file is a real
    # preference, and the wallpaper in particular is genuine runtime state:
    # noctalia records the current image per monitor under `wallpaper.…` and
    # dropping it would reset the desktop to `wallpaper.default.path` on every
    # `home-manager switch`.
    if [ -f "$stateFile" ]; then
      trimmed="$(${pkgs.coreutils}/bin/mktemp)"

      # Delete each `[section]` and `[section.sub]` block by tracking which
      # table the current line belongs to: a header switches tables, and
      # everything until the next header belongs to the one just seen.
      ${pkgs.gawk}/bin/awk '
        /^[[:space:]]*\[\[?[a-zA-Z0-9_.-]+\]?\]/ {
          drop = ($0 ~ /^[[:space:]]*\[\[?(lockscreen_widgets|desktop_widgets)([].[])/)
        }
        !drop
      ' "$stateFile" > "$trimmed"

      if ! ${pkgs.diffutils}/bin/cmp -s "$stateFile" "$trimmed"; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp -f "$trimmed" "$stateFile"
        echo "noctalia: dropped persisted widget placements from settings.toml;" >&2
        echo "noctalia: the ones declared in config.toml apply again." >&2
      fi

      ${pkgs.coreutils}/bin/rm -f "$trimmed"
    fi
  '';
in
{
  config = lib.mkIf useNoctalia {
    home.packages = [
      pkg

      # `ddcutil` has to be findable by name: noctalia gates its whole DDC/CI
      # backend on `commandExists("ddcutil")` and nixpkgs' wrapper only
      # prefixes gitMinimal onto its PATH. See the brightness block above.
      pkgs.ddcutil
      pkgs.procps

      # The community fastfetch hook is jq from end to end — it parses the
      # config, merges the rendered colours in and writes it back — and jq is
      # not one of the tools NixOS puts in the system profile by default.
      # Everything else those hooks reach for (bash, sed, awk, coreutils,
      # findutils) already is.
      pkgs.jq

      # Poppins, for the lock screen clock. A font referenced by family name
      # in a config file has to actually be installed for fontconfig to
      # resolve it — otherwise the clock silently falls back to the default
      # sans and the setting looks like it did nothing.
      pkgs.poppins
    ];

    # --- satisfying the template hooks -------------------------------------
    #
    # Each of these declares the exact line the matching builtin template's
    # `apply.sh` looks for, so the hook finds its work already done and leaves
    # the store-managed file alone. See the `templates` note in `settings`.

    # kitty/apply.sh rewrites kitty.conf to contain `include
    # themes/noctalia.conf` exactly once, then writes it back only `if ! cmp -s`
    # — so with the line already present its rewrite is a no-op and it never
    # touches the read-only symlink.
    #
    # mkAfter for the same reason ./default.nix uses it: `extraConfig` is a
    # `lines` option and kitty takes the last value for any key.
    programs.kitty.extraConfig = lib.mkAfter ''

      include themes/noctalia.conf
    '';

    # btop/apply.sh greps for `^color_theme\s*=\s*"noctalia"` and does nothing
    # when it matches. Set here rather than in home/common/btop.nix because
    # that module is shared with root and the server, where noctalia never
    # runs and the theme file would never be written.
    #
    # mkForce because btop.nix names `tokyo-night` outright; two plain
    # definitions of one option is a conflict rather than an override, and
    # that host's btop should follow the session's palette rather than a
    # theme picked once.
    programs.btop.settings.color_theme = lib.mkForce "noctalia";

    # starship is the exception, and the only place a declarative file has to
    # become a mutable one.
    #
    # Every other template renders a *side* file and the app is pointed at it
    # with one line — which is why declaring that line up front makes the hook
    # a no-op. starship has no include mechanism at all, so its hook has to
    # splice the palette bodily into starship.toml between two markers, and
    # the spliced content changes with every theme. There is no line to
    # pre-declare, and a store symlink cannot be written.
    #
    # So on a noctalia host home-manager stops owning the file and seeds a
    # real one instead. `home/common/files/starship.toml` stays the source of
    # truth — the activation below re-seeds whenever it changes — and the hook
    # owns only what is between its markers.
    home.activation.noctaliaStarshipSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      starshipTarget="${config.xdg.configHome}/starship.toml"
      starshipSeed=${../../common/files/starship.toml}

      if [ ! -e "$starshipTarget" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm644 "$starshipSeed" "$starshipTarget"
      else
        # Compare what the seed owns, not what the hook owns: strip the
        # palette block before diffing so a theme change never looks like the
        # file drifting from the source.
        stripped="$(${pkgs.coreutils}/bin/mktemp)"
        ${pkgs.gnused}/bin/sed \
          '/^# >>> NOCTALIA STARSHIP PALETTE >>>$/,/^# <<< NOCTALIA STARSHIP PALETTE <<<$/d' \
          "$starshipTarget" > "$stripped"

        if ! ${pkgs.diffutils}/bin/diff -q \
          <(${pkgs.gnused}/bin/sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$stripped") \
          <(${pkgs.gnused}/bin/sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$starshipSeed") >/dev/null; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm644 "$starshipSeed" "$starshipTarget"
          echo "noctalia: re-seeded starship.toml from home/common/files/starship.toml;" >&2
          echo "noctalia: its palette block returns on the next colour-scheme change." >&2
        fi

        ${pkgs.coreutils}/bin/rm -f "$stripped"
      fi
    '';

    # --- satisfying the community template hooks ---------------------------
    #
    # The two that need something to exist before they can do anything. Both
    # are seed-if-missing rather than store symlinks, for the starship reason
    # above: the hook edits the file in place, and a symlink into the store
    # cannot be written.

    # fastfetch/apply.sh refuses to run without ~/.config/fastfetch/config.jsonc
    # ("run fastfetch once to generate a default config first"), then parses it
    # with `jq empty` and refuses again if it is JSONC rather than strict JSON.
    # It merges the rendered `logo` and `display` objects into whatever else is
    # there, so the seed only has to be a valid config — the colours arrive on
    # the first theme change.
    #
    # Deliberately not the same file as the fish greeting's. That one is
    # ~/.smallfetch.jsonc (home/common/shell.nix), it is shared with root and
    # the servers where noctalia never runs, and it carries comments — all
    # three of which rule it out as the thing this hook rewrites.
    home.activation.noctaliaFastfetchSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      fastfetchTarget="${config.xdg.configHome}/fastfetch/config.jsonc"

      if [ ! -e "$fastfetchTarget" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm644 \
          ${./fastfetch-config.json} "$fastfetchTarget"
      fi
    '';

    # papirus-icons/apply.sh picks the palette entry closest to the accent and
    # hands it to the bundled `papirus-folders`, which recolours the folder
    # icons *in place*. It looks for a writable copy at
    # ~/.local/share/icons/Papirus and, not finding one, copies /usr/share/icons
    # /Papirus — a path that does not exist on NixOS, so the hook fails on every
    # colour change with "Papirus Icons are not installed".
    #
    # This is the copy it is looking for. Three theme directories rather than
    # one because papirus-folders recolours whichever of them it finds, and the
    # session names Papirus-Dark (../niri/default.nix, and `[Icons] Theme` in
    # the kdeglobals template); a recoloured Papirus with an untouched
    # Papirus-Dark beside it would be work nothing ever displays.
    #
    # -R rather than -a: the -Dark and -Light trees are almost entirely
    # relative symlinks into Papirus, and dereferencing them would turn a
    # hundred megabytes into several times that. --no-preserve=mode because
    # the store is read-only and the whole point is a tree that can be written.
    #
    # Only when missing. This runs on every activation and re-copying an icon
    # theme each time would be minutes of I/O for nothing — and it would also
    # throw away the recolouring the hook has already done.
    home.activation.noctaliaPapirusSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      iconRoot="${config.xdg.dataHome}/icons"

      for variant in Papirus Papirus-Dark Papirus-Light; do
        if [ ! -d "$iconRoot/$variant" ]; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$iconRoot"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp -R --no-preserve=mode \
            "${pkgs.papirus-icon-theme}/share/icons/$variant" "$iconRoot/$variant"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod -R u+w "$iconRoot/$variant"
        fi
      done
    '';

    # Before the unit is (re)started, so a stale overrides file is dealt with
    # rather than crashing the shell on the way in. See reconcileOverrides.
    home.activation.noctaliaReconcileOverrides = lib.hm.dag.entryAfter [ "writeBoundary" ] reconcileOverrides;

    # The extension manifest the community VS Code template's output belongs
    # to. That template renders only the colour theme —
    # `~/.vscode/extensions/noctalia.noctaliatheme-0.0.5/themes/NoctaliaTheme-color-theme.json`
    # — because upstream assumes the matching marketplace extension is
    # installed. Without a package.json beside it that directory is not an
    # extension at all, and VS Code logs a parse failure for it on every start.
    #
    # Fifteen lines of manifest is cheaper than the marketplace round trip, and
    # it is also what makes the id in `community_ids` mean something: with this
    # here, "NoctaliaTheme" is a theme that can be picked from the palette.
    # ./vscode.nix keeps "Niri" — the local template, which follows
    # `theme.mode` into a light uiTheme where this one is fixed dark — as the
    # one actually selected.
    home.file.".vscode/extensions/noctalia.noctaliatheme-0.0.5/package.json".text = builtins.toJSON {
      name = "noctaliatheme";
      displayName = "Noctalia Theme";
      description = "The live Noctalia palette, rendered by the community VS Code template.";
      version = "0.0.5";
      publisher = "noctalia";
      engines.vscode = "^1.70.0";
      categories = [ "Themes" ];
      contributes.themes = [
        {
          label = "NoctaliaTheme";
          uiTheme = "vs-dark";
          path = "./themes/NoctaliaTheme-color-theme.json";
        }
      ];
    };

    # One assignment, because these cannot be split.
    #
    # `xdg.configFile."a".text = …` and `xdg.configFile = { … }` are two
    # definitions of the same attribute as far as the Nix language is
    # concerned — not the module system, which would merge them — so writing
    # the static entries in path form and the generated ones as a set is
    # "attribute 'xdg.configFile' already defined". The palettes have to be
    # built with `mapAttrs'`, so everything joins them in the set.
    xdg.configFile = {
      # cava/apply.sh wants a `[color]` section already naming the theme, and
      # exits 1 with an error if the config file is missing entirely. cava is
      # installed for the bar visualiser (see ./default.nix) but its config was
      # never managed, so this is both the file it needs and the line it checks.
      "cava/config".text = ''
        # Managed by home/joshr/niri/noctalia.nix.
        #
        # The palette is not here: noctalia renders it to
        # ~/.config/cava/themes/noctalia and this points cava at it. The theme
        # file is rewritten on every colour-scheme change.
        [color]
        theme = "noctalia"
      '';

      # Hand starship.toml over to the activation step below, which seeds a
      # real file the template hook can splice into.
      "starship.toml".enable = lib.mkForce false;

      "noctalia/config.toml".source = validatedConfig;
      "noctalia/templates/kdeglobals".source = ./noctalia-templates/kdeglobals;
      "noctalia/templates/spotify.css".source = ./noctalia-templates/spotify.css;
      "noctalia/templates/system-palette.conf".source = ./noctalia-templates/system-palette.conf;
      "noctalia/templates/vencord.css".source = ./noctalia-templates/vencord.css;
      "noctalia/templates/vscode-package.json".source = ./noctalia-templates/vscode-package.json;
      "noctalia/templates/vscode.json".source = ./noctalia-templates/vscode.json;
      "noctalia/templates/wofi.css".source = ./noctalia-templates/wofi.css;
      "noctalia/templates/wofi-emoji.css".source = ./noctalia-templates/wofi-emoji.css;
    }
    // lib.mapAttrs' (
      name: palette:
      lib.nameValuePair "noctalia/palettes/${name}.json" {
        source = jsonFormat.generate "noctalia-palette-${name}.json" palette;
      }
    ) paletteSet.palettes;

    # Local v5 plugin: the slot collapses completely unless GameMode has an
    # active client. It sits immediately after Privacy in the bar list above.
    xdg.dataFile."noctalia/plugins/gamemode-indicator" = {
      source = ./noctalia-plugins/gamemode-indicator;
      recursive = true;
    };

    # As a user service rather than a niri `spawn-at-startup`, matching how
    # waybar was run and for a better reason than waybar had: naming the
    # generated config in `X-Restart-Triggers` means a `home-manager switch`
    # that changes any of it restarts the shell on its own. Under
    # `spawn-at-startup` a config change would sit there until the next login.
    systemd.user.services.noctalia = {
      Unit = {
        Description = "noctalia — Wayland desktop shell";
        Documentation = "https://docs.noctalia.dev/v5/";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        X-Restart-Triggers = [ "${validatedConfig}" ];
      };

      Service = {
        ExecStart = noctalia;
        Restart = "on-failure";
      };

      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    # --- what noctalia takes over -----------------------------------------
    #
    # Each of these is a daemon whose job is now a section of the config above.
    # `mkForce` rather than plain `false` because the modules that enable them
    # set it directly, and this has to win over that without those files
    # needing to know this one exists.
    #
    # Two of them would actively fight noctalia rather than merely duplicate
    # it: dunst and noctalia both claim org.freedesktop.Notifications on the
    # session bus, and cliphist and noctalia both watch the Wayland selection,
    # so every copy would be recorded twice.
    services.dunst.enable = lib.mkForce false;
    services.swayosd.enable = lib.mkForce false;
    services.cliphist.enable = lib.mkForce false;
    services.swayidle.enable = lib.mkForce false;

    # waybar is disabled in ./waybar.nix rather than here — it also sets an
    # `ExecStart` override on its own systemd unit, and a unit definition left
    # behind by a disabled module would still be written out as a fragment.

    # wofi stays enabled, and is no longer the launcher. `theme-menu`,
    # `wallpaper-menu` and `session-menu` in ./scripts.nix all use it as a
    # plain `--dmenu` and keep working; only Mod+D moves.

    # GameMode is represented by the local plugin above. The old waybar signal
    # hooks remain harmless; the plugin polls without starting gamemoded.
  };
}
