{ config, niriTheming, ... }:

# The niri half of Firefox: point its chrome stylesheets at the active theme.
#
# It does *not* claim the http(s) handler any more — Vivaldi is the default
# again, and `xdg.mimeApps` is owned by ./browser.nix. Two modules both
# writing that option would be a conflict rather than a merge, so if this
# file is ever re-enabled in ./default.nix, the mimeApps block stays there
# and not here.
#
# This is separate from ../firefox.nix — which sets up the browser itself and
# is shared with the Plasma hosts — for the same reason the kitty `include`
# lives in ./default.nix rather than in ../kitty.nix: the Plasma hosts have no
# niri theme state, so `${niriTheming.activeDir}` doesn't exist there and both
# symlinks would dangle.
let
  # Both halves have to agree on the profile directory. Reading it out of the
  # firefox module rather than repeating the string means a rename is an
  # evaluation error here instead of a silently unthemed browser.
  profilePath = config.programs.firefox.profiles.joshr.path;
  chromeDir = ".mozilla/firefox/${profilePath}/chrome";
in
{
  # Out-of-store symlinks, not store files, for the same reason kdeglobals is
  # one: the switcher moves ~/.local/state/niri-theme/active, and a file
  # home-manager wrote into the store can't follow it.
  #
  # Firefox reads both of these once, while it's starting. A theme switch
  # therefore lands at the next browser start — like Dolphin, and unlike
  # kitty or waybar, which the switcher can nudge.
  home.file."${chromeDir}/userChrome.css".source =
    config.lib.file.mkOutOfStoreSymlink "${niriTheming.activeDir}/firefox-userChrome.css";

  home.file."${chromeDir}/userContent.css".source =
    config.lib.file.mkOutOfStoreSymlink "${niriTheming.activeDir}/firefox-userContent.css";
}
