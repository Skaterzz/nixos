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
      Mod+1 through Mod+5 end up scattered across displays. Naming an output
      pins them all to it.

      null leaves them unpinned, which is what a single-display machine
      wants.
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
