{ config, niriTheming, ... }:

# The niri half of Firefox: point its chrome stylesheets at the active theme.
#
# It does *not* claim the http(s) handler any more — Vivaldi is the default
# again, and the handlers moved out of home-manager entirely: they're a system
# baseline in modules/nixos/default-apps.nix now, so that a settings panel can
# still override them. If this file is ever re-enabled in ./default.nix, it
# should not reintroduce `xdg.mimeApps`; that option owns
# ~/.config/mimeapps.list and is what stopped every "make this the default"
# from saving.
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
  #
  # The attribute is `config.home.username` because that is what ../firefox.nix
  # names the profile after — every account wearing this profile gets its own
  # directory, and none of them has "joshr" written into it.
  profilePath = config.programs.firefox.profiles.${config.home.username}.path;
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
