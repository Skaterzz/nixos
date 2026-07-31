{ config, niriTheming, ... }:

# The niri half of the browser: point Firefox's chrome stylesheets at the
# active theme, and make it the handler for links.
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

  # Default browser for the session: what `xdg-open`, and so every "open link"
  # in every app, resolves to.
  #
  # The Plasma hosts don't get this — they set `kdeglobals.General
  # .BrowserApplication` instead (see ../plasma.nix), and letting home-manager
  # take ownership of ~/.config/mimeapps.list underneath a running Plasma
  # means its "Default Applications" page silently can't save. Under niri
  # nothing else is writing that file.
  #
  # The trade is that "Set as default" inside Firefox, and any "always use
  # this app" choice, now fails to persist: the file is a read-only symlink
  # into the store. Change it here instead.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
    };
  };
}
