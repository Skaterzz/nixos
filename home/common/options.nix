{ lib, ... }:

# Small set of shape options so the hosts — and joshr vs root — can share the
# same home modules. Declared separately from the modules that consume them so
# those don't have to split into options/config blocks.
{
  options.local.shell.fastfetchGreeting = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether fish's greeting runs fastfetch.

      Mirrors the username branch in the dotfiles' config.fish.tmpl: root gets
      an empty greeting, everyone else gets the fastfetch one. Also controls
      whether fastfetch and ~/.smallfetch.jsonc are installed at all.
    '';
  };


  options.local.niri.shell = lib.mkOption {
    type = lib.types.enum [
      "waybar"
      "noctalia"
    ];
    default = "waybar";
    description = ''
      Which desktop shell the niri session runs.

      "waybar" is the assembled stack: waybar, dunst, swayosd, wofi, cliphist,
      swayidle and hyprlock, each configured by its own module under
      home/joshr/niri/ and themed by theming.nix rendering themes.nix into
      seven different config formats.

      "noctalia" replaces all seven with one Quickshell process reading one
      TOML file — home/joshr/niri/noctalia.nix — which disables the daemons it
      subsumes. themes.nix stays the source of colour either way: the palettes
      are rendered into noctalia's own format by noctalia-palettes.nix, and
      `theme-apply` remains the switcher, so kitty, Dolphin and VS Code follow
      a theme change exactly as they do under waybar.

      Not everything survives the crossing, and both losses are indicators
      that were rarely on screen: the gamemode pad has no noctalia widget
      (its waybar module was a polled script, and custom_button has no exec),
      and the lock screen loses the album art, media buttons, battery readout
      and greetings that `lock-session` builds hyprlock configs for. The
      `local.niri.lock*` options are therefore only read under "waybar".
    '';
  };

  options.local.niri.noctaliaSourcePatches = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to build Noctalia with this repository's C++ extras: animated
      lock/unlock transitions, content-sized text OSDs, and the customized
      control-panel identity and detail colours, plus the relative MPRIS IPC
      actions retained for compatibility.

      Enabling this changes the Noctalia derivation and therefore compiles it
      locally instead of using the binary from cache.nixos.org. Disabling it
      keeps the complete generated Noctalia configuration, palettes, plugins,
      templates and theme-sync hooks, but uses stock pkgs.noctalia and its
      upstream behaviour for those source-only features.
    '';
  };

  options.local.waybar.cavaInBar = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether the bar and Noctalia lock screen carry audio visualisers.

      Named for waybar because that is where it started, and still read by
      both shells — it answers the same question either way. Under waybar it
      adds the `custom/cava` module, a script feeding the bar one frame of
      glyphs per line (cavaBar in home/joshr/niri/scripts.nix); under noctalia
      it adds the compact bar widget and the full-output lock-screen visualizer,
      both of which read PipeWire directly and need no helper.
    '';
  };

  options.local.niri.randomLockGreetings = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether Hyprlock chooses a randomized, time-aware greeting each time the
      niri session locks. When disabled, it always shows the ordinary
      "Welcome, <first name>" greeting.
    '';
  };

  options.local.niri.timeBasedLockGreetings = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Gives time based greetings: "Good {Morning, Afternoon, Evening}, <first name>".
    '';
  };

  options.local.niri.lockAlbumArtBackground = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether Hyprlock replaces the wallpaper with a blurred version of the
      current track's album art. When disabled, the selected wallpaper stays
      behind the lock screen while its other media widgets keep working.
    '';
  };

  options.local.niri.lockAlbumArtCover = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether Hyprlock shows the current track's album cover above the now
      playing label. This is independent of the album-art background.
    '';
  };

  options.local.niri.lockBatteryIndicator = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether Hyprlock shows the battery charge in the bottom-right corner of
      the lock screen.

      On by default, and safe to leave on everywhere: the battery has to be
      found before it can be drawn. `lock-session` looks for a system battery
      each time it writes the config and leaves the widget out of the file
      entirely when the machine hasn't got one, so a desk draws nothing here
      whatever this is set to — which is also why there is no per-host `false`
      for the machines without a battery. Turning it off is for a laptop whose
      corner you would rather have empty.
    '';
  };

  # Per-host display layout for niri. Rendered into `output` blocks in
  # config.kdl by home/joshr/niri/niri.nix.
  #
  # Leave empty to let niri auto-detect, which is right for a laptop whose
  # external displays change. Set it where the layout is fixed and you care
  # about the exact mode — a monitor's advertised preferred mode is often not
  # its highest refresh rate.
  options.local.niri.outputs = lib.mkOption {
    default = [ ];
    description = "niri output configuration, one entry per display.";
    example = lib.literalExpression ''
      [
        {
          name = "DP-3";
          mode = "2560x1440@180.000";
          position = { x = 0; y = 0; };
          focusAtStartup = true;
        }
      ]
    '';
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = ''
              Connector name, e.g. "DP-3" or "eDP-1". `niri msg outputs` lists
              them along with every mode each display actually supports.
            '';
          };

          mode = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "2560x1440@180.000";
            description = ''
              `WIDTHxHEIGHT@REFRESH`. The refresh rate is optional but worth
              being explicit about, and it must match a mode the display
              reports — niri falls back to the preferred mode and logs a
              warning if it doesn't. Copy it verbatim from `niri msg outputs`.
            '';
          };

          position = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  x = lib.mkOption { type = lib.types.int; };
                  y = lib.mkOption { type = lib.types.int; };
                };
              }
            );
            default = null;
            description = ''
              Top-left corner in the global logical coordinate space. These
              are logical pixels, so a scaled display occupies
              width / scale — lay the next one out from there, not from its
              physical width.
            '';
          };

          scale = lib.mkOption {
            type = lib.types.nullOr (lib.types.either lib.types.int lib.types.float);
            default = null;
            description = "Fractional scale. Omit for 1.";
          };

          transform = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "90";
            description = ''Rotation: "90", "180", "270", "flipped", etc.'';
          };

          variableRefreshRate = lib.mkEnableOption "VRR / adaptive sync on this output";

          focusAtStartup = lib.mkEnableOption ''
            starting the session focused on this output.

            niri has no "primary display" concept, so this is the closest
            equivalent. To also pin workspaces to a display, give them an
            `open-on-output` in the workspace declarations
          '';

          off = lib.mkEnableOption "disabling this output entirely";
        };
      }
    );
  };

  options.local.niri.lockClockOutputs = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "eDP-1" ];
    description = ''
      Connectors that get a clock on noctalia's lock screen, for hosts that
      do not pin their display layout.

      Only consulted when `local.niri.outputs` is empty. noctalia places lock
      screen widgets by pixel coordinate per output, so the clock's position
      is normally computed from the mode already declared there — one place
      for the resolution, and a monitor change moves the clock with it. A host
      that leaves the layout to niri's auto-detection has no mode to read, so
      this names the connectors instead and the position falls back to a 1080p
      centre. noctalia clamps widget coordinates to the output, so on a panel
      that is not 1080p the clock is off-centre rather than off-screen.

      `niri msg outputs` prints the connector names. Only read under
      `local.niri.shell = "noctalia"`; the hyprlock screen the waybar stack
      uses draws its own clock and needs none of this.
    '';
  };

  options.local.niri.brightness.device = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "ddcci5";
    description = ''
      Backlight device that speaks for "the display" — the one the bar's
      brightness reading and the OSD both report. The keys still drive every
      display; this only decides which one is *quoted*.

      Nothing picks that consistently on its own, which is the reason this
      exists. waybar's backlight module, given no device, takes the one with
      the highest `max_brightness` and breaks ties in udev enumeration order;
      the `brightness` helper takes whichever sorts first in
      /sys/class/backlight. On a laptop those are the same single panel. On a
      desk with one `ddcci*` device per monitor they are two different numbers
      about two different screens, neither of them necessarily the monitor in
      front of you.

      null leaves that as it was — right for a machine with one panel, and for
      one where you haven't decided yet. A name that matches no device falls
      back to the same place, with a warning on stderr from the helper.

      Find the name by asking each device which monitor it is. `idModel` and
      `idSerial` come from the ddcci device the backlight sits on:

          for d in /sys/class/backlight/*; do
            printf '%s\t%s\t%s\n' "''${d##*/}" \
              "$(cat "$d/device/idModel" 2>/dev/null)" \
              "$(cat "$d/device/idSerial" 2>/dev/null)"
          done

      Note that a `ddcci*` name is its i2c adapter number
      (`ddcci<adapter>`), so it follows the bus the monitor is on rather than
      the monitor. Moving a cable to a different port can renumber it.
    '';
  };

  options.local.niri.workspaceOutput = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "DP-3";
    description = ''
      Output the named workspaces open on, as an `open-on-output` on each
      `workspace` declaration.

      niri creates a workspace on whichever output is focused at the time, so
      without this the numbered workspaces land wherever you happened to be —
      the Mod+<n> binds end up scattered across displays. Naming an output
      pins them all to it.

      null leaves them unpinned, which is what a single-display machine
      wants.
    '';
  };

  # OpenRGB's options are not here. `local.openrgb.autostart`, `.profile` and
  # `.applyOnResume` are declared on the NixOS side (modules/nixos/options.nix)
  # and read from this side through `osConfig`, because the session isn't the
  # only thing that uses them: the daemon and the after-resume re-apply are
  # system services (modules/nixos/openrgb.nix), and a profile name that the
  # session and the resume service disagreed about would be a bug nobody would
  # notice until a suspend.

  # wallhaven.cc's toplist, downloaded into
  # ~/.local/share/wallpapers/WallhavenFlake from the `wallhaven-toplist`
  # flake input. See home/joshr/wallhaven.nix.
  options.local.wallhaven.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Keep ~/.local/share/wallpapers/WallhavenFlake in sync with the
      `wallhaven-toplist` flake input.

      Only reaches machines that import home/joshr/wallhaven.nix, which is
      the desktop base — the server and root have no wallpapers at all. Turn
      it off and the directory is simply left where it stands: nothing
      removes it, because nothing runs. `rm -r` it yourself if you want it
      gone.
    '';
  };

  options.local.wallhaven.count = lib.mkOption {
    type = lib.types.ints.between 1 24;
    default = 20;
    description = ''
      How many of the listing's wallpapers to keep — the 20 in "top 20".

      The ceiling is a page of wallhaven's API, which holds 24 results and is
      what the input asks for. Lowering this deletes the surplus on the next
      switch, same as the toplist moving on would.
    '';
  };

  options.local.wallhaven.timeout = lib.mkOption {
    type = lib.types.ints.positive;
    default = 600;
    description = ''
      Seconds the download run may take before it gives up and leaves the
      rest for next time.

      This exists because the run happens inside `nixos-rebuild switch`. A
      network that drops packets rather than refusing connections would
      otherwise let twenty files' worth of timeouts and retries stack up into
      a rebuild that looks hung. Nothing is lost when the budget runs out:
      what did download stays, nothing is deleted, and the next activation or
      login picks up where this one stopped.
    '';
  };

  options.local.plasma.secondaryMonitorPanel = lib.mkEnableOption ''
    the status bar on the second monitor (screen 1).

    On the desk this is the top bar carrying the pager, window list, clock,
    media controls and volume. A single-screen machine has nothing to put it
    on — Plasma would place it on the only display, on top of the panels
    already there
  '';
}
