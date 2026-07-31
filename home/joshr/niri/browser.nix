{ browserDesktopFiles, ... }:

# Default browser for the niri session: what `xdg-open`, and so every "open
# link" in every app, resolves to.
#
# Which browser it is lives in ../browser.nix; this is only the niri-side
# wiring. The Plasma hosts don't get this — they set
# `kdeglobals.General.BrowserApplication` instead (see ../plasma.nix), because
# letting home-manager take ownership of ~/.config/mimeapps.list underneath a
# running Plasma means its "Default Applications" page silently can't save.
# Under niri nothing else is writing that file.
#
# The trade is that "Set as default" inside a browser, and any "always use
# this app" choice, now fails to persist: the file is a read-only symlink into
# the store. Change it here instead.
{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = browserDesktopFiles;
      "application/xhtml+xml" = browserDesktopFiles;
      "x-scheme-handler/http" = browserDesktopFiles;
      "x-scheme-handler/https" = browserDesktopFiles;
      "x-scheme-handler/about" = browserDesktopFiles;
      "x-scheme-handler/unknown" = browserDesktopFiles;
    };
  };
}
