{ lib, ... }:

# System-level `local.*` options.
#
# The home-manager equivalents live in home/common/options.nix; these are the
# ones a NixOS module needs to read, which can't come from there.
{
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
}
