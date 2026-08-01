{ ... }:

# Which app opens which kind of file, for everything that isn't the browser.
#
# Why this has to be declared rather than clicked
# -----------------------------------------------
# Dolphin's "Open With… → Remember application association for this type of
# file" writes ~/.config/mimeapps.list. Under niri that file is a read-only
# symlink into the store, because ./browser.nix sets `xdg.mimeApps` and that
# makes home-manager its owner. So the checkbox appears to work, and the
# association is gone again at the next launch.
#
# Adding KDE System Settings back would not change that. Its Default
# Applications page writes the same unwritable file, so it would fail in
# exactly the same way — the app was dropped in d7faf9e for being a settings
# shell with no Plasma to configure, and it was never what stored this.
#
# The trade is deliberate, and ./browser.nix documents it along with the way
# out: declare the association instead. This is that.
#
# Why its own module
# ------------------
# ./browser.nix is about which browser is *the* browser, and these aren't
# that. They don't collide: `defaultApplications` is an attrset, so modules
# contributing different MIME types merge. The conflict ./firefox.nix warns
# about is two modules claiming the *same* type — that one is real, and it is
# why the http(s) handlers stay in ./browser.nix alone.
#
# `xdg.mimeApps.enable` is not set here for the same reason; ./browser.nix
# already turns it on, and this file only adds entries.
#
# On the desktop file names
# -------------------------
# Two spellings, for the reason ../browser.nix lists two for Vivaldi:
# mimeapps.list treats a `;`-separated value as a preference list and skips
# entries it can't resolve, and naming the wrong one is a silent failure
# rather than an error. KDE renamed its desktop entries to reverse-DNS years
# ago, so `org.kde.gwenview.desktop` is the live name and the bare one is
# insurance against that not being true on some future bump.
#
# That same skipping is what makes this safe on laptop-niri, which imports
# ./default.nix and therefore this file, but not
# modules/nixos/desktop-apps.nix — where gwenview is actually installed. The
# entry simply doesn't resolve there and the next handler wins.
let
  gwenview = [
    "org.kde.gwenview.desktop"
    "gwenview.desktop"
  ];
in
{
  # Raster formats only. SVG is deliberately not here — gwenview will open
  # one, but a vector file is more often wanted in a browser or an editor, and
  # claiming it here would take that choice away silently.
  #
  # Video and audio are not claimed either, though haruna and elisa are both
  # installed alongside gwenview in modules/nixos/desktop-apps.nix. This is
  # the file to add them to if the same thing turns out to be true of them.
  xdg.mimeApps.defaultApplications = {
    "image/jpeg" = gwenview;
    "image/png" = gwenview;
    "image/gif" = gwenview;
    "image/webp" = gwenview;
    "image/tiff" = gwenview;
    "image/bmp" = gwenview;
    "image/avif" = gwenview;
    "image/heif" = gwenview;
  };
}
