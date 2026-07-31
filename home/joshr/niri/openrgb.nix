{ config, lib, pkgs, ... }:

# OpenRGB's session side: the tray applet niri starts at login, and its icon.
#
# The daemon is a system service (`services.hardware.openrgb.enable` in
# modules/nixos/gaming.nix) and the package is installed in ../home.nix. Only
# the desktop-facing parts are here — the niri `spawn-at-startup` that launches
# this lives in niri.nix, which reads the same options.
let
  cfg = config.local.openrgb;

  # A plain monochrome stand-in for OpenRGB's multicolour logo: three arcs
  # around a hub, which is the same shape read in one colour.
  #
  # Grey rather than `currentColor`: symbolic recolouring only happens for
  # consumers that opt into it, and everywhere else `currentColor` falls back
  # to CSS's default of black — invisible against this desktop's dark menus.
  # A fixed light grey is legible on every surface it can land on.
  monochromeIcon = pkgs.writeText "openrgb-mono.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
      <g fill="none" stroke="#d0d0d0" stroke-width="2.2" stroke-linecap="round">
        <path d="M 10.44 3.14 A 9 9 0 0 1 21.00 12.00"/>
        <path d="M 20.46 15.08 A 9 9 0 0 1 7.50 19.79"/>
        <path d="M 5.11 17.79 A 9 9 0 0 1 7.50 4.21"/>
      </g>
      <circle cx="12" cy="12" r="3.2" fill="#d0d0d0"/>
    </svg>
  '';
in
{
  xdg.dataFile = lib.mkIf cfg.monochromeIcon {
    "icons/hicolor/scalable/apps/openrgb-mono.svg".source = monochromeIcon;
  };

  # Overrides the package's own OpenRGB.desktop rather than adding a second
  # entry: the desktop *ID* is the filename, so writing OpenRGB.desktop into
  # ~/.local/share/applications shadows the one in the profile. Renaming it
  # would put two OpenRGB entries in the launcher instead of replacing one.
  #
  # Everything but the icon is copied from upstream's entry, because shadowing
  # is all-or-nothing — the file that wins supplies every field, and dropping
  # StartupWMClass here would break the window-to-launcher association.
  xdg.desktopEntries = lib.mkIf cfg.monochromeIcon {
    OpenRGB = {
      name = "OpenRGB";
      genericName = "RGB Lighting Control";
      comment = "Open source RGB lighting control";
      exec = "openrgb";
      icon = "openrgb-mono";
      terminal = false;
      type = "Application";
      categories = [ "Utility" ];
      settings = {
        Keywords = "RGB;LED;Lighting;";
        StartupWMClass = "OpenRGB";
      };
    };
  };
}
