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
# The shell is `pkgs.noctalia` and everything below is written out by hand.
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

  pkg = pkgs.noctalia;
  noctalia = lib.getExe pkg;

  paletteSet = import ./noctalia-palettes.nix { inherit lib; };

  tomlFormat = pkgs.formats.toml { };
  jsonFormat = pkgs.formats.json { };

  # The same directories the scripts in ./scripts.nix use, spelled the same
  # way. `stateDir` in particular is the fan-out point shared with the SDDM,
  # Limine, and Spotify syncs — see the hooks below.
  stateDir = "${config.home.homeDirectory}/.local/state/niri-theme";
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
  # Run after the builtin templates, read the resolved surface colour back
  # from their niri fragment, and add the one node they omit. This works for
  # every palette source without trying to reproduce Noctalia's colour
  # resolution. Replacing the file atomically also gives niri one complete
  # config change to live-reload instead of a partially appended KDL block.
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
        's/^[[:space:]]*inactive-color[[:space:]]*"\(#[0-9A-Fa-f]\{6\}\)".*/\1/p' \
        "$fragment" | head -n1)"
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

  # Colour scheme -> everything that is not the shell.
  #
  # `theme-apply` is the switcher: it repoints ~/.local/state/niri-theme/active
  # at the chosen theme's rendered configs, reloads kitty, tells KDE its
  # palette changed, writes the state file the greeter watches, and — under
  # noctalia — sets the palette. That covers every route through the keybinds.
  # It does not cover the colour scheme being changed from noctalia's own
  # Settings window, which is the case this closes.
  #
  # **Why this does not loop.** The environment flag below tells `theme-apply`
  # that noctalia is already the source of the change, so it applies every
  # non-shell consumer but does not send `color-scheme-set` back to noctalia.
  # Running the switcher even when the name is unchanged is intentional: it
  # atomically replaces `current`, which reliably wakes the SDDM and Limine
  # system path units and Spotify's user path unit after a missed or
  # late-starting sync.
  #
  # `color-scheme-get` prints `<source> <name>`; anything other than a `custom`
  # source is a palette that did not come from themes.nix and that there is no
  # theme directory for, so it is left alone rather than guessed at.
  themeResync = pkgs.writeShellApplication {
    name = "noctalia-theme-resync";
    runtimeInputs = [
      pkg
      niriScripts.themeApply
    ];
    text = ''
      line="$(noctalia msg color-scheme-get 2>/dev/null || true)"

      # shellcheck disable=SC2086
      set -- $line
      source="''${1:-}"
      name="''${2:-}"

      [ "$source" = "custom" ] || exit 0
      [ -n "$name" ] || exit 0

      NIRI_THEME_FROM_NOCTALIA=1 theme-apply "$name"
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

  # One login box, two lock-safe buttons, and two clock widgets per output.
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

        # Noctalia's own default login box is capped at 810 logical pixels and
        # sits 84px above the bottom edge. Declaring it here lets us turn off
        # only its shared session row while keeping the rest of its regular
        # layout (media, weather, password, caps lock, and keyboard layout).
        loginW = lib.min 810 (w - 48);
        loginH = 190;
        loginCy = h - 84 - (loginH / 2);

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
            shadow = true;
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
        (lib.nameValuePair "login_box_${o.name}" {
          type = "login_box";
          output = o.name;
          cx = cx;
          cy = loginCy;
          box_width = loginW;
          box_height = loginH;

          settings = {
            show_session_buttons = false;
            show_weather = false;
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
      session.actions = [
        {
          action = "lock";
          label = "Lock";
        }
        {
          action = "lock_and_suspend";
          label = "Lock and suspend";
        }
        {
          action = "command";
          label = "Switch user";
          glyph = "users";
          command = lib.getExe niriScripts.switchUser;
        }
        {
          action = "reboot";
          label = "Reboot";
        }
        {
          action = "shutdown";
          label = "Power off";
          variant = "destructive";
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
        "user"
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

          # Battery and the requested Caffeine toggle drawn flush as one
          # control. Caffeine takes the slot that previously showed the power
          # profile, so the right-hand cluster does not grow wider.
          "group:power"

          "wallpaper"
          "control-center"
          "session"
        ];

      capsule_group = [
        {
          id = "power";
          members = [
            "battery"
            "caffeine"
          ];
        }
      ];
    };

    widget = {
      # Who the session belongs to, first thing on the bar — the same
      # `custom/user` slot, with the same glyph and the same name read out of
      # `config.home.username` rather than written down, so a second user's
      # generation renders their own.
      #
      # It has gained a job: under waybar this was static text with no `exec`
      # and no action, and here it opens the launcher, which is the entry
      # point wofi had no bar slot for at all.
      user = {
        type = "custom_button";
        glyph = "user";
        label = config.home.username;
        tooltip = "Applications";
        command = "noctalia msg panel-toggle launcher";
      };

      # Make the numbered workspaces at the left edge easier to scan without
      # increasing the height of the whole bar.
      workspaces.scale = 1.25;

      clock = {
        format = "{:%I:%M %p   %a, %b %d}";
        tooltip_format = "{:%A, %B %d, %Y}";
      };

      active_window = {
        max_length = 300;
        display = "icon_and_text";
      };

      media = {
        max_length = 200;
        hide_when_no_media = true;
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
      # Two mechanisms share this job, and the split is not arbitrary.
      #
      # theming.nix renders all 29 palettes into the config formats this repo
      # already had to speak — niri's KDL, kitty's include, kdeglobals for
      # Dolphin and the KDE file dialogs, VS Code, firefox, wofi — and hands
      # each app a path under ~/.local/state/niri-theme/active. `theme-apply`
      # moves that symlink. That machinery predates noctalia, works under both
      # shells, and feeds SDDM, Limine, and the themed Spotify launcher too.
      #
      # noctalia's templates now cover the rest, including the gap theming.nix
      # left: **GTK**. Nothing in theming.nix ever wrote a GTK stylesheet, so
      # GTK apps and every portal/file-chooser dialog they open kept the stock
      # Adwaita palette while the rest of the session changed colour.
      #
      # `kcolorscheme` is the one still left off. Its post-action writes
      # ~/.config/kdeglobals unconditionally, and ./default.nix points that at
      # the active theme as an out-of-store symlink — so the two would be
      # fighting over one file that theming.nix already keeps correct. Every
      # other builtin that touches something home-manager owns is handled by
      # pre-declaring what its hook looks for; see below.
      #
      # --- and how it reaches everything that is not the shell -------------
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
          "starship"
        ];

        # Community templates are a runtime fetch from api.noctalia.dev, which
        # is against the grain of a config that pins every input in flake.lock.
        enable_community_templates = false;
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
      transition_duration = 1500;

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
    # ddcutil stays off, and that is the important line in this block.
    #
    # modules/nixos/ddcci.nix loads ddcci-backlight, an out-of-tree driver that
    # speaks DDC/CI in the kernel and registers each external monitor as an
    # ordinary /sys/class/backlight/ddcci* device. The whole point of taking
    # that route was that everything driving the laptop's internal panel then
    # works on the desk unchanged. So noctalia should reach the monitors the
    # same way it reaches a laptop panel — through sysfs, which its automatic
    # backend already finds — and `enable_ddcutil` would put a second, slower
    # userspace DDC/CI implementation on top of the one already in the kernel.
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
    # What this leaves: two writers for the same monitors. The idle dim in
    # `idle.behavior.dim` still goes through the `brightness` helper, which
    # writes sysfs through ddcci-backlight, while noctalia writes over i2c
    # directly. They agree — both end at the monitor's own luminance register
    # — but a dim landing in the middle of a `ddcutil detect` is a DDC/CI
    # round trip contending with another, and DDC/CI is slow and not
    # especially robust. Worth knowing if brightness ever feels sticky right
    # as the screen dims.
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
    # swayidle's three timers, at the same three timeouts.
    #
    # The 240s dim is a `command` because noctalia has no dim action, and it
    # runs the same `brightness` helper swayidle ran — which matters for the
    # reason that helper exists: it steps *every* backlight device, where
    # anything driving only the first one moves one of the desk's two monitors.
    # It also records the pre-dim level itself rather than using brightnessctl's
    # `--save`, which had no idea whether it had already saved and would strand
    # the screen at 20%.
    idle.behavior = {
      dim = {
        enabled = true;
        timeout = 240;
        action = "command";
        command = "${lib.getExe niriScripts.brightness} dim 20";
        resume_command = "${lib.getExe niriScripts.brightness} restore";
      };

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

    # Before the unit is (re)started, so a stale overrides file is dealt with
    # rather than crashing the shell on the way in. See reconcileOverrides.
    home.activation.noctaliaReconcileOverrides = lib.hm.dag.entryAfter [ "writeBoundary" ] reconcileOverrides;

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
    }
    // lib.mapAttrs' (
      name: palette:
      lib.nameValuePair "noctalia/palettes/${name}.json" {
        source = jsonFormat.generate "noctalia-palette-${name}.json" palette;
      }
    ) paletteSet.palettes;

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

    # The gamemode indicator has no widget here. waybar's `custom/gamemode`
    # was a script polled on an interval and poked with SIGRTMIN+9 by the
    # hooks in modules/nixos/gaming.nix; noctalia's `custom_button` draws a
    # fixed label and has no exec, so there is nothing to poll with. Those
    # hooks are left alone — their `pkill` finds no waybar and exits into a
    # `|| true`.
  };
}
