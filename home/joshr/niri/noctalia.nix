{
  config,
  lib,
  pkgs,
  inputs,
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
# largely to restart them all in the right order (see `theme-apply` in
# ./scripts.nix).
#
# noctalia is all of those in one Quickshell process reading one TOML file.
# Turning it on with `local.niri.shell = "noctalia"` disables the daemons it
# subsumes, and the mapping is one-for-one:
#
#     waybar    -> [bar.main] and the widget list below
#     dunst     -> [notification]
#     swayosd   -> [osd]
#     wofi      -> [shell.launcher]  (still installed; see the note further down)
#     cliphist  -> [shell] clipboard_*
#     swayidle  -> [idle.behavior.*]
#     awww      -> [wallpaper]
#     hyprlock  -> [lockscreen]
#
# What it does not replace: themes.nix stays the source of truth for colour.
# See the "Colour" section below, which is the part of this migration with an
# actual decision in it.
#
# Not imported conditionally
# --------------------------
# `imports` cannot depend on `config` without sending the module system round
# in a circle, so noctalia's own home-manager module is imported on every niri
# host and everything this file *sets* hangs off one `lib.mkIf` instead. The
# upstream module is inert until `programs.noctalia.enable`, so a waybar host
# pays for it in evaluation time and nothing else.
let
  useNoctalia = config.local.niri.shell == "noctalia";

  paletteSet = import ./noctalia-palettes.nix { inherit lib; };

  # Same two directories the scripts in ./scripts.nix use, spelled the same
  # way. `wallpaperDir` is the tree home/joshr/wallhaven.nix fills from the
  # locked wallhaven listing, which is why the picker below is pointed at the
  # root of it and told to recurse rather than at WallhavenFlake/ directly:
  # the hand-kept wallpapers sit alongside it in the same tree.
  wallpaperDir = "${config.home.homeDirectory}/.local/share/wallpapers";
  screenshotDir = "${config.home.homeDirectory}/Pictures/Screenshots";

  # The visualiser is a per-host opt-in, exactly as it was on waybar — the
  # option is still `local.waybar.cavaInBar` because it still answers the same
  # question, and renaming it would touch both host files for no gain.
  #
  # cava itself is gone from the picture. waybar had no visualiser, so
  # `custom/cava` was a shell script feeding it one frame per line (cavaBar in
  # ./scripts.nix); noctalia draws its own from the PipeWire stream and needs
  # no helper. The script and the `cava` package stay for the full-size
  # terminal version, which is what they were also good for.
  visualiser = lib.optional config.local.waybar.cavaInBar "audio_visualizer";

  # The version actually being built, read back off the package rather than
  # from `inputs`, so an override is checked too. See the assertion at the
  # bottom of this file for why it is checked at all.
  version = config.programs.noctalia.package.version;
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  config = lib.mkIf useNoctalia {
    programs.noctalia = {
      enable = true;

      # The binary comes from nixpkgs; only the module comes from the flake.
      #
      # nixpkgs carries two attributes and the names are a trap. `noctalia` is
      # 5.0.0-beta.7 — the v5 line, and what this file is written for.
      # `noctalia-shell` is 4.7.7: it kept the repository's *old* name, which
      # upstream changed to `noctalia` at v5, so the more official-looking name
      # is the stale one. The assertion at the bottom of this file exists in
      # part to make picking the wrong one a build error instead of a session
      # that comes up with half its settings ignored.
      #
      # Why nixpkgs' build rather than the flake's: upstream's flake exposes a
      # package but publishes no substituter for it — the cachix workflow's
      # cache name is a CI secret and there is no `nixConfig` block naming one
      # — so `packages.default` means compiling a Qt/C++ project locally on
      # every machine. nixpkgs' build is on the usual binary cache.
      #
      # What that costs: the module is from the flake's `main` (5.0.0) and the
      # binary is the beta.7 tag, where `validateConfig` is the flake module
      # running *this* binary over the config generated from `settings` below.
      # `settings` is written against main's schema, so a key added after
      # beta.7 fails the build. That is a loud failure naming the key, and the
      # fix is one line — put `inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default`
      # here and take the local compile until nixpkgs catches up.
      package = pkgs.noctalia;

      # As a user service rather than a niri `spawn-at-startup`, matching how
      # waybar was run and for a better reason than waybar had: the upstream
      # unit carries `X-Restart-Triggers` naming the generated config and every
      # palette, so a `home-manager switch` that changes any of them restarts
      # the shell on its own. Under `spawn-at-startup` a config change would
      # sit there until the next login.
      systemd.enable = true;

      # Every palette in themes.nix, rendered into noctalia's colour-scheme
      # format. One JSON file per theme in ~/.config/noctalia/palettes/, named
      # for the theme id — which is what `custom_palette` below and
      # `color-scheme-set custom <name>` both take. See ./noctalia-palettes.nix.
      customPalettes = paletteSet.palettes;

      # `validateConfig` is left at its default of true on purpose. It runs
      # `noctalia config validate` over the generated TOML at build time, so a
      # key that has been renamed upstream fails the build with the offending
      # line rather than being dropped in silence and leaving a setting here
      # that looks applied and isn't. This file is written from noctalia's
      # documented schema, so that check is the thing standing between the
      # documentation being out of date and the setting quietly not working.

      settings = {
        shell = {
          # The bar's font under waybar, kept so the glyphs in the widget
          # labels have the same metrics they did. noctalia has one font
          # family for all shell text and no separate mono field.
          font_family = "FiraCode Nerd Font";

          # 12-hour with the leading zero and month before day, matching the
          # waybar clock. Worth knowing: waybar rendered its clock through
          # libfmt, where glibc's `%-I` no-padding extension does not exist and
          # broke the whole format string; noctalia supports `%-I`, so
          # "7:30 PM" is available here if the leading zero ever annoys.
          time_format = "{:%I:%M %p}";
          date_format = "%a, %b %d";

          # A polkit agent already runs in this session —
          # modules/nixos/niri.nix starts polkit-kde-agent as a user service,
          # because the disk tools in modules/nixos/disk-managements.nix need
          # one. Two agents racing for the same authority is the failure this
          # avoids.
          polkit_agent = false;

          # Clipboard history, replacing cliphist. 300 entries is the cap the
          # cliphist unit carried (`-max-items 300`), chosen there because
          # images are stored too and an entry can cost a screenshot's worth
          # of disk rather than a line's.
          clipboard_enabled = true;
          clipboard_history_max_entries = 300;

          # niri's overview gets a type-to-launch search. This is niri-specific
          # and off by default upstream; it is the overview equivalent of the
          # launcher bind, and costs nothing when not typed into.
          niri_overview_type_to_launch_enabled = true;

          settings_show_advanced = true;

          privacy = {
            # cava opens a PipeWire source to read the output stream, which is
            # not a microphone in use — without this the privacy indicator sits
            # lit whenever the visualiser is running. This is the same
            # exclusion the old `waybar-microphone-privacy` helper made in jq
            # (see ./privacy.nix), now one setting.
            mic_filter_regex = "cava";
          };

          launcher = {
            categories = true;
            show_icons = true;
            sort_by_usage = true;

            # No currency rates. This config pins its inputs and the shell
            # should not be reaching out to a third-party API on its own; the
            # calculator provider still does arithmetic offline.
            fetch_exchange_rates = false;
          };

          screenshot = {
            # Same directory the `screenshot` helper writes to, so region
            # captures and noctalia's own full-screen captures land together.
            directory = screenshotDir;

            # satty for annotation, which is the whole reason region capture
            # was a script rather than a niri action. `-f -` reads the image
            # on stdin.
            pipe_command = "${pkgs.satty}/bin/satty -f -";
            copy_to_clipboard = true;
          };

          panel = {
            # Frosted panels rather than flat ones, matching the bar's own
            # 0.88 opacity below.
            transparency_mode = "soft";
            borders = true;
            shadow = true;
          };
        };

        # --- bar --------------------------------------------------------
        #
        # The waybar layout, slot for slot. Its geometry came from
        # `programs.waybar.settings.main` and its look from the generated
        # stylesheet (renderWaybarCss in ./theming.nix); both are settings here
        # because noctalia has no stylesheet to render.
        #
        #   height 34        -> thickness
        #   spacing 4        -> widget_spacing
        #   margin-top 6     -> margin_edge
        #   margin-left 10   -> margin_ends
        #   border-radius 12 -> radius
        #   alpha(@bg, 0.88) -> background_opacity
        bar.main = {
          position = "top";
          thickness = 34;
          widget_spacing = 4;
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

          # Right-hand cluster, in waybar's order. Three slots are new and one
          # is gone; everything else is the module that was there before.
          #
          # New: `notifications` (waybar had no history to open), `clipboard`
          # and `control-center`. The control centre is where wifi, bluetooth,
          # audio devices and the power profile all get a real panel instead of
          # a click-through to nm-connection-editor, blueman-manager and
          # pavucontrol — which is most of what the old right-click actions on
          # those modules were for.
          #
          # Gone: the gamemode indicator. See the note at the bottom of this
          # file; it is the one widget that has no equivalent here.
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

              # battery and the power profile drawn flush as one control, which
              # is what waybar's `group/power` did. A capsule group is
              # noctalia's version of the same idea: several widgets in one
              # pill, referenced from the lane as `group:<id>`.
              #
              # Unconditional on every host for the reason the waybar group was:
              # both halves hide themselves when they have nothing to say, so
              # the desk draws the profile alone and the laptop draws both.
              "group:power"

              "lock_keys"
              "caffeine"
              "clipboard"
              "lock"
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
          # `custom/user` slot, with the same glyph and the same name read out
          # of `config.home.username` rather than written down, so a second
          # user's generation renders their own.
          #
          # It has gained a job. Under waybar this was static text with no
          # `exec` and no action; here it opens the launcher, which is the
          # entry point wofi had no bar slot for at all.
          user = {
            type = "custom_button";
            glyph = "user";
            label = config.home.username;
            tooltip = "Applications";
            command = "noctalia msg panel-toggle launcher";
          };

          clock = {
            # The waybar centre format: time, a gap, then the short date.
            # waybar's `format-alt` (the long date on click) is the tooltip
            # here — noctalia has no click-to-swap-format, and a tooltip is
            # where the longer version was wanted anyway.
            format = "{:%I:%M %p   %a, %b %d}";
            tooltip_format = "{:%A, %B %d, %Y}";
          };

          active_window = {
            # waybar's `niri/window` had max-length 70 and a rewrite table that
            # swapped "… — Mozilla Firefox" for a Firefox glyph. noctalia draws
            # the app icon beside the title from the window's own app-id, which
            # is the same idea done properly — the rewrites existed because
            # waybar could only match on the title string.
            max_length = 70;
            display = "icon_and_text";
          };

          media = {
            # waybar's mpris was title + artist, truncated to 30 characters
            # total, and hidden outright when nothing was playing.
            max_length = 30;
            hide_when_no_media = true;
          };

          network = {
            show_label = true;
          };

          # Lock, immediately left of the session button — the one-click
          # version of the thing done most often, which is why it keeps its own
          # slot rather than living behind the session panel that also offers
          # it. Same reasoning as the waybar module it replaces.
          lock = {
            type = "custom_button";
            glyph = "lock";
            tooltip = "Lock the session";
            command = "noctalia msg session lock";
          };
        };

        # --- colour -----------------------------------------------------
        #
        # `custom` rather than `builtin` or `wallpaper`: the palettes are the
        # ones in themes.nix, written out by ./noctalia-palettes.nix.
        #
        # `mode = "dark"` is not really a mode here. Each theme in themes.nix
        # is a finished palette that is already light or dark — gruvbox-light
        # is the light one — so both variants of each generated palette hold
        # the same colours and this only picks which of two identical halves
        # gets read. See the header of ./noctalia-palettes.nix.
        theme = {
          mode = "dark";
          source = "custom";
          custom_palette = paletteSet.default;

          templates = {
            # Both template systems off, and this is the one place where
            # noctalia does *less* than the setup it replaces — deliberately.
            #
            # noctalia can push its palette into other apps' configs by
            # rendering templates over them. So can this repo: theming.nix
            # already renders all 29 themes into kitty, kdeglobals, GTK, wofi,
            # dunst, swayosd, VS Code, firefox and niri, and hands each app a
            # path under ~/.local/state/niri-theme/active. Both mechanisms
            # write the same files, and on this machine only one of them can:
            # ~/.config/kitty/kitty.conf and ~/.config/kdeglobals are
            # home-manager symlinks into the store, so a template hook that
            # tried to edit them would fail read-only every time the theme
            # changed.
            #
            # So theming.nix keeps that job and `theme-apply` stays the way to
            # change theme — it repoints the symlink, reloads kitty and Dolphin
            # as it always did, and now also tells noctalia which palette to
            # paint itself with. One switcher, one source of truth, and the
            # apps that were themed before are themed the same way after.
            #
            # The cost is that changing the colour scheme from noctalia's own
            # Settings window moves the shell and nothing else. `theme-apply`,
            # and the Mod+Shift+T / Mod+Ctrl+T binds that call it, are the
            # supported route.
            enable_builtin_templates = false;

            # Community templates are additionally a runtime fetch from
            # api.noctalia.dev, which is against the grain of a config that
            # pins every input in flake.lock.
            enable_community_templates = false;
          };
        };

        # --- wallpaper --------------------------------------------------
        #
        # Replaces awww and the `wallpaper-set` / `wallpaper-random` /
        # `wallpaper-restore` trio in ./scripts.nix. noctalia remembers the
        # selection itself, so the `spawn-at-startup` that restored it at login
        # has nothing left to do.
        wallpaper = {
          enabled = true;
          directory = wallpaperDir;

          # `crop` fills the screen and trims the overflow, which is what awww
          # was given and what a 16:9 toplist wants.
          fill_mode = "crop";
          transition_duration = 1500;

          # Recursive because home/joshr/wallhaven.nix drops the locked top 20
          # into WallhavenFlake/ under this directory, alongside the
          # hand-kept ones. The old picker globbed the tree for the same reason.
          automation.recursive = true;

          default.path = "${wallpaperDir}/nixos.png";
        };

        # --- notifications ----------------------------------------------
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

        # --- OSD --------------------------------------------------------
        #
        # swayosd, whose whole reason for existing was that niri has no OSD and
        # a volume or brightness key was otherwise silent. Placed where swayosd
        # put it: low and centred, clear of the bar at the top.
        #
        # The `volume` and `brightness` helpers in ./scripts.nix drew this by
        # calling swayosd-client after making the change. noctalia watches the
        # devices itself, so the OSD appears whatever moved the level — a key,
        # the bar, or the pre-lock dim.
        osd = {
          position = "bottom_center";
          background_opacity = 0.97;
          offset_x = 20;
          offset_y = 8;

          kinds = {
            # swayosd drew volume and brightness. The rest are new, and the
            # two worth naming are `lock_keys` — which is the caps-lock
            # indicator the bar also carries — and `privacy`, which pops when
            # something opens the microphone or starts capturing the screen.
            volume = true;
            brightness = true;
            lock_keys = true;
            privacy = true;
          };
        };

        # --- brightness -------------------------------------------------
        #
        # ddcutil stays off, and that is the important line in this block.
        #
        # modules/nixos/ddcci.nix loads ddcci-backlight, an out-of-tree driver
        # that speaks DDC/CI in the kernel and registers each external monitor
        # as an ordinary /sys/class/backlight/ddcci* device. The whole point of
        # taking that route was that everything driving the laptop's internal
        # panel then works on the desk unchanged, with no second code path. So
        # noctalia should reach the monitors the same way it reaches a laptop
        # panel — through sysfs, which its automatic backend already finds —
        # and turning on `enable_ddcutil` would put a second, slower userspace
        # DDC/CI implementation on top of the one already in the kernel.
        #
        # `local.niri.brightness.device` has no equivalent here and is not read
        # under noctalia. It exists because waybar's backlight module and the
        # `brightness` helper each picked "the display" by a different rule and
        # could disagree about which monitor the bar was quoting; noctalia
        # reports the focused monitor's own backlight, which is the answer that
        # option was trying to approximate.
        brightness.enable_ddcutil = false;

        # --- idle -------------------------------------------------------
        #
        # swayidle's three timers, at the same three timeouts.
        #
        # The 240s dim is a `command` because noctalia has no dim action, and
        # it runs the same `brightness` helper swayidle ran — which matters for
        # the reason that helper exists: it steps *every* backlight device,
        # where anything driving only the first one moves one of the desk's two
        # monitors. It also records the pre-dim level itself rather than using
        # brightnessctl's `--save`, which had no idea whether it had already
        # saved and would strand the screen at 20%.
        #
        # What is deliberately gone: the `when-active` guard each of these
        # carried. That existed because several people can be logged in at
        # once, each session runs its own swayidle, and niri keeps the idle
        # clock running in a session that has been switched away from — so a
        # background session's dim landed on the screen of whoever was actually
        # at the machine. noctalia's idle service is driven by the compositor's
        # own idle-notify rather than by a timer of its own, so a session that
        # is not being drawn does not accumulate idle time to act on.
        idle = {
          behavior = {
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
        };

        # --- lock screen ------------------------------------------------
        #
        # This is the largest reduction in the migration and it is worth being
        # plain about. `lock-session` in ./scripts.nix builds a hyprlock config
        # per invocation carrying a blurred album-art background, the album
        # cover, media transport buttons, a battery readout and a time-aware
        # greeting — around a thousand lines of shell whose options are
        # `local.niri.lockAlbumArt*`, `.lockBatteryIndicator` and the two
        # greeting flags. noctalia's lock screen has none of that.
        #
        # What it has instead is a blurred snapshot of the desktop, which is
        # the one thing hyprlock was being fed album art to approximate. The
        # `local.niri.lock*` options are not read under noctalia; they still
        # drive the hyprlock screen on a waybar host.
        lockscreen = {
          enabled = true;
          blurred_desktop = true;
          blur_intensity = 0.5;
          tint_intensity = 0.3;
        };

        # Sampling for the control centre's system tab. The defaults poll CPU
        # and memory every 2s; nothing here is on the bar, so the cost is only
        # paid while the panel is open.
        system.monitor.enabled = true;
      };
    };

    # --- what noctalia takes over ---------------------------------------
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

    # wofi stays enabled, and is no longer the launcher.
    #
    # `theme-menu`, `wallpaper-menu` and `session-menu` in ./scripts.nix all
    # use it as a plain `--dmenu`, and they keep working: the stylesheet they
    # read is still rendered per theme and still reachable through the active
    # symlink. Only Mod+D moves, from wofi's `drun` mode to noctalia's
    # launcher — which sorts by usage, filters by category, and carries the
    # calculator and emoji providers the separate bemoji picker existed for.

    # --- the major version is part of this file's contract ----------------
    #
    # Everything in `settings` above is written against noctalia's **v5** TOML
    # schema — `[bar.<name>]` with `start`/`center`/`end` lanes, `[widget.<id>]`
    # instances, `theme.source = "custom"` reading `palettes/<name>.json`. v4
    # spelled several of those differently: colour schemes lived in
    # `colorschemes/<name>/<name>.json`, and the bar was configured elsewhere.
    #
    # The flake input follows `main`, and upstream's convention is that main is
    # the current major with the previous one parked on a branch of its own —
    # `legacy-v4` at the time of writing. So main becomes v6 the day v6 lands.
    # flake.lock means that cannot happen by surprise, but the first
    # `nix flake update` afterwards would otherwise swap the shell for one
    # reading a schema this file was not written for.
    #
    # `validateConfig` already catches the loud half of that: a key that has
    # been renamed or removed fails the build with the offending line. This
    # catches the half it cannot — a schema that still accepts every key here
    # and means something different by them.
    #
    # If this fires, the fix is to read the upgrade notes and revisit
    # `settings` and ./noctalia-palettes.nix, not to widen the bound.
    assertions = [
      {
        assertion = lib.versionAtLeast version "5" && lib.versionOlder version "6";
        message = ''
          home/joshr/niri/noctalia.nix is written against noctalia v5's config
          schema, but the package resolves to ${version}.

          Check what moved (https://docs.noctalia.dev), update `settings` and
          home/joshr/niri/noctalia-palettes.nix to match, then widen the bound
          in the assertion at the bottom of noctalia.nix.

          To carry on with the version that works while doing that, pin the
          input in flake.nix to the last v5 ref:

              noctalia.url = "github:noctalia-dev/noctalia/<v5 tag or commit>";
        '';
      }
    ];

    # The gamemode indicator has no widget here.
    #
    # waybar's `custom/gamemode` was a script polled on an interval and poked
    # with SIGRTMIN+9 by the start/end hooks in modules/nixos/gaming.nix.
    # noctalia's `custom_button` draws a fixed label and has no exec, so there
    # is nothing to poll with; the equivalent would be a Luau plugin, which is
    # more than a pad-shaped glyph that is absent nearly all the time is worth.
    # The hooks in gaming.nix are left alone — their `pkill` simply finds no
    # waybar and exits non-zero into a `|| true`.
  };
}
