{ pkgs, ... }:

# Which browser is *the* browser.
#
# Vivaldi, on every host. Firefox is still installed and still themed (see
# ./firefox.nix) — this is only about which one links open in.
#
# The desktop file name
# ---------------------
# Vivaldi's upstream .deb ships `/usr/share/applications/vivaldi-stable.desktop`
# and nixpkgs copies it across under that name. It rewrites the *contents*
# (`Exec=`, `Icon=`) but never renames the file, so the desktop entry ID is
# `vivaldi-stable.desktop` and not `vivaldi.desktop`. Naming the wrong one is
# a silent failure — mimeapps.list keeps whatever string it is given and
# xdg-open simply finds nothing — which is why both spellings are listed
# wherever the format allows a fallback list.
#
# Where the default is actually set differs by session, and neither mechanism
# reaches the other:
#
#   niri    `xdg.mimeApps`, in ./niri/browser.nix
#   Plasma  `kdeglobals.General.BrowserApplication`, in ./plasma.nix
#
# See "The browser" in the README for why Plasma doesn't get the mimeApps
# treatment.
let
  desktopFile = "vivaldi-stable.desktop";
in
{
  # Installed here rather than in modules/nixos/desktop-apps.nix, which only
  # the gamestation-niri host imports — the default browser has to exist on
  # all four desktop hosts, and this file is reached from ./home.nix, which
  # every one of them shares.
  home.packages = [ pkgs.vivaldi ];

  _module.args.browserDesktopFiles = [
    desktopFile
    # Kept as a fallback in case a future nixpkgs revision renames the file
    # to match the binary. mimeapps.list treats a `;`-separated value as a
    # preference list and skips entries it can't resolve.
    "vivaldi.desktop"
  ];

  # For CLI tools that shell out to a browser (gh, glab, xdg-open fallbacks).
  #
  # A bare name rather than a store path on purpose: baking
  # /nix/store/…-vivaldi/bin/vivaldi into the session environment pins it to
  # the build that existed at login, so it keeps launching the old browser
  # (or nothing at all, once that path is collected) until the next logout.
  # home.packages above is what puts it on PATH.
  home.sessionVariables.BROWSER = "vivaldi";
}
