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
  # way. `stateDir` in particular is shared with the SDDM sync — see the hooks
  # below.
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
  # Carry a change noctalia made outward to something that isn't noctalia.
  # Both are given the environment variables the shell exports for the hook
  # (`NOCTALIA_WALLPAPER_PATH` here) rather than being told anything on the
  # command line.

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

  # Colour scheme -> everything that is not the shell.
  #
  # `theme-apply` is the switcher: it repoints ~/.local/state/niri-theme/active
  # at the chosen theme's rendered configs, reloads kitty, tells KDE its
  # palette changed, writes the state file the greeter watches, and — under
  # noctalia — sets the palette. That covers every route through the keybinds.
  # It does not cover the colour scheme being changed from noctalia's own
  # Settings window, which is the case this closes.
  #
  # **Why this does not loop.** `theme-apply` writes `current` *before* it
  # calls `color-scheme-set`, so when its own call fires this hook the name
  # noctalia reports already matches `current` and the guard below returns.
  # A change made in the GUI does not match, so `theme-apply` runs once, which
  # fires the hook once more, which then matches and stops.
  #
  # `color-scheme-get` prints `<source> <name>`; anything other than a `custom`
  # source is a palette that did not come from themes.nix and that there is no
  # theme directory for, so it is left alone rather than guessed at.
  themeResync = pkgs.writeShellApplication {
    name = "noctalia-theme-resync";
    runtimeInputs = [
      pkg
      niriScripts.themeApply
      pkgs.coreutils
    ];
    text = ''
      line="$(noctalia msg color-scheme-get 2>/dev/null || true)"

      # shellcheck disable=SC2086
      set -- $line
      source="''${1:-}"
      name="''${2:-}"

      [ "$source" = "custom" ] || exit 0
      [ -n "$name" ] || exit 0

      current="$(cat ${lib.escapeShellArg "${stateDir}/current"} 2>/dev/null || true)"
      [ "$name" != "$current" ] || exit 0

      theme-apply "$name"
    '';
  };

  # --- lock screen ------------------------------------------------------
  #
  # noctalia draws the login box itself, centred and near the bottom, and it
  # already carries the things a lock screen is asked for: who is logging in,
  # what is playing, caps lock, the keyboard layout and the session buttons.
  # Nothing here has to place it — a `login_box` entry in `lockscreen_widgets`
  # only *overrides* its position, so leaving it out is what keeps the layout
  # correct on a display whose resolution this file does not know.
  #
  # What the login box has no equivalent for is the time, so that is the one
  # widget below — and widgets *are* placed by pixel coordinate, per output.
  # Hence the arithmetic: the position is derived from the mode already
  # declared in `local.niri.outputs` rather than written down a second time,
  # so a monitor change moves the clock with it. Coordinates are clamped to
  # the output by noctalia, so being wrong here is off-centre rather than
  # off-screen.
  #
  # **Battery is not here, and cannot be.** noctalia has no battery widget for
  # the lock screen or the desktop — the widget types are clock, label,
  # button, sysmon, media_player, weather, sticker, volume, the two
  # visualisers and login_box, and sysmon's stats are CPU, GPU, RAM, swap and
  # network with nothing for the power supply. There is no official plugin for
  # it either. The charge is on the bar and in the control centre; the
  # hyprlock screen under `local.niri.shell = "waybar"` still draws it, which
  # is what `local.niri.lockBatteryIndicator` still controls.

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

  lockClockWidgets = lib.listToAttrs (
    map (
      o:
      let
        parsed = if o.mode == null then null else parseMode o.mode;
        scale = if o.scale == null then 1 else o.scale;

        # Logical pixels, which is the space widgets are positioned in — a
        # scaled output occupies mode / scale, the same arithmetic the
        # `position` fields in local.niri.outputs are written in.
        w = builtins.floor ((if parsed == null then 1920 else parsed.w) / (scale + 0.0));
        h = builtins.floor ((if parsed == null then 1080 else parsed.h) / (scale + 0.0));
      in
      lib.nameValuePair "clock_${o.name}" {
        type = "clock";
        output = o.name;

        # Horizontally centred, a bit above the third — high enough to clear
        # the login box, low enough not to sit on the very top edge.
        cx = w / 2;
        cy = builtins.floor (h * 0.30);

        settings = {
          clock_style = "digital";

          # Time over date, matching the bar's own 12-hour format. `%-I` drops
          # the leading zero, which reads better at lock-screen size than the
          # bar's padded `%I` does at 13px.
          format = "{:%-I:%M %p}\n{:%A, %B %-d}";
          center_text = true;

          # No panel behind it. A slab of surface colour under a clock on top
          # of a wallpaper is the least elegant thing the widget can do, and
          # it is also the expensive one — dropping it drops a rounded-rect
          # and an alpha layer per output per frame.
          background = false;

          # Which makes the text shadow load-bearing rather than decorative:
          # it is the only thing keeping the time legible over a pale
          # wallpaper now that there is no panel behind it.
          shadow = true;
        };
      }
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
      #   caffeine   a control-centre shortcut, and Mod+Shift+I
      #   lock_keys  the caps-lock OSD says it louder, and this only ever had
      #              anything to show while a key was actually held on
      #
      # What stays is either a live reading (brightness, volume, network,
      # bluetooth, battery, power profile) or an indicator that means
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

          # battery and the power profile drawn flush as one control, which is
          # what waybar's `group/power` did. Unconditional on every host for
          # the reason the waybar group was: both halves hide themselves when
          # they have nothing to say, so the desk draws the profile alone and
          # the laptop draws both.
          "group:power"

          "control-center"
          "session"
        ];

      capsule_group = [
        {
          id = "power";
          members = [
            "battery"
            "power_profile"
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

      clock = {
        format = "{:%I:%M %p   %a, %b %d}";
        tooltip_format = "{:%A, %B %d, %Y}";
      };

      active_window = {
        max_length = 70;
        display = "icon_and_text";
      };

      media = {
        max_length = 30;
        hide_when_no_media = true;
      };

      network = {
        show_label = true;
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
      # shells, and is what the SDDM greeter reads too.
      #
      # noctalia's templates fill the gap it left: **GTK**. Nothing in
      # theming.nix ever wrote a GTK stylesheet, so GTK apps and every
      # portal/file-chooser dialog they open kept the stock Adwaita palette
      # while the rest of the session changed colour. `gtk3` and `gtk4` write
      # ~/.config/gtk-{3,4}.0/noctalia.css and add an `@import` to gtk.css,
      # which home-manager does not manage here — and their apply hook already
      # knows about NixOS, replacing a read-only symlink with a real file
      # rather than failing on it.
      #
      # `qt` is the same idea for qt5ct/qt6ct, which it writes as plain side
      # files with no hook at all.
      #
      # Deliberately **not** enabled, and each for the same reason — the file
      # they want to edit is a read-only store symlink here:
      #
      #   kcolorscheme  its post-action writes ~/.config/kdeglobals, which
      #                 ./default.nix points at the active theme
      #   kitty         its hook writes through ~/.config/kitty/kitty.conf
      #   btop          its hook edits ~/.config/btop/btop.conf
      #   niri          its hook adds an include to ~/.config/niri/config.kdl
      #
      # All four are already themed by theming.nix, so nothing is missing —
      # they would only be a second writer for a file that already has one.
      templates = {
        enable_builtin_templates = true;
        builtin_ids = [
          "gtk3"
          "gtk4"
          "qt"
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
    brightness.enable_ddcutil = false;

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
      enabled = lockClockWidgets != { };
      widget = lockClockWidgets;
    };

    # --- hooks ------------------------------------------------------------
    hooks = {
      wallpaper_changed = lib.getExe sddmWallpaperSync;
      colors_changed = lib.getExe themeResync;
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
in
{
  config = lib.mkIf useNoctalia {
    home.packages = [ pkg ];

    xdg.configFile = {
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
