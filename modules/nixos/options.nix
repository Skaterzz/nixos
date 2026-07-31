{ lib, ... }:

# System-level `local.*` options.
#
# The home-manager equivalents live in home/common/options.nix; these are the
# ones a NixOS module needs to read, which can't come from there.
{
  options.local.sddm.compositor = lib.mkOption {
    type = lib.types.enum [
      "kwin"
      "weston"
    ];
    default = "weston";
    description = ''
      Which compositor SDDM's Wayland greeter runs under.

      Defaults to weston rather than NixOS's own default of kwin. On this
      machine — NVIDIA, two displays — kwin_wayland left the primary display
      black: it could be watched attempting a modeset and then giving up.
      That happened with a generated output config, with a copied one, and
      with none at all, which rules the config out and leaves the compositor.

      weston is a far smaller thing to have between SDDM and the hardware. It
      has no output config to get wrong and no session-restore state, so it
      brings up what it detects and nothing else.

      "kwin" restores the stock behaviour, and is what to use if weston turns
      out worse. If neither works, the next step is the X11 greeter
      (`services.displayManager.sddm.wayland.enable = false`), which is the
      most reliable multi-monitor NVIDIA option and costs an X server used
      only to draw the login screen.
    '';
  };

  options.local.sddm.syncGreeterDisplays = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Generate the SDDM greeter's `kwinoutputconfig.json` from
      `local.niri.outputs`, so the login screen comes up with the same modes
      and arrangement as the session.

      The greeter runs its own kwin_wayland and cannot see niri's config, so
      without this it auto-detects: every display lights up, but at whatever
      mode and arrangement kwin settles on.

      Set false to go back to auto-detection. This is the escape hatch if a
      generated layout ever leaves a display dark — though note that changing
      it needs a rebuild, so the faster fix from a TTY is to delete
      /var/lib/sddm/.config/kwinoutputconfig.json.

      Hosts with no outputs configured (the laptop) auto-detect regardless.
    '';
  };

  options.local.sddm.greeterModes = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Also write each display's `mode` into the greeter's output config,
      rather than letting kwin pick the preferred one.

      Off by default because this is the one setting here that can leave a
      display black instead of degrading. KWin looks the mode up among what
      the connector reports and hands it to a modeset; if nothing matches
      exactly — DRM reporting 179998 mHz where the config says 180000, or a
      disagreement over the mode flags — the modeset fails and the output
      stays dark. High-refresh DisplayPort links are the most fragile case.

      Leaving it off still honours the arrangement, scale, rotation and which
      display is primary. Only the refresh rate is kwin's choice, which on a
      login screen costs nothing.

      Turn it on only if the greeter genuinely comes up at the wrong
      resolution, and be ready to recover from a TTY.
    '';
  };
}
