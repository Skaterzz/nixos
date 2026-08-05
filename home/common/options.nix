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


  options.local.waybar.cavaInBar = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable cava in waybar in niri
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
