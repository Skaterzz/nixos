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
# Where the default is actually set
# ---------------------------------
# `modules/nixos/default-apps.nix`, for both sessions now. It writes the
# handlers to /etc/xdg/mimeapps.list, which the XDG spec reads *below*
# ~/.config/mimeapps.list — so the default applies everywhere while a choice
# made in a settings panel still wins.
#
# It used to be `xdg.mimeApps` in ./niri/browser.nix, and the Plasma hosts
# were deliberately kept away from it because home-manager owning
# ~/.config/mimeapps.list stops Plasma's Default Applications page saving.
# Moving down a level removed that objection, so the split is gone and both
# sessions are configured the same way. `kdeglobals.General.BrowserApplication`
# in ./plasma.nix is still set and still agrees.
{
  # Installed here rather than in modules/nixos/desktop-apps.nix, which only
  # the gamestation-niri host imports — the default browser has to exist on
  # all four desktop hosts, and this file is reached from ./home.nix, which
  # every one of them shares.
  home.packages = [ pkgs.vivaldi ];

  # The `browserDesktopFiles` module arg that used to live here is gone with
  # ./niri/browser.nix, its only consumer. Both spellings are now named in
  # modules/nixos/default-apps.nix, which is a NixOS module and can't read a
  # home-manager arg — the note above about the entry ID applies there.

  # For CLI tools that shell out to a browser (gh, glab, xdg-open fallbacks).
  #
  # A bare name rather than a store path on purpose: baking
  # /nix/store/…-vivaldi/bin/vivaldi into the session environment pins it to
  # the build that existed at login, so it keeps launching the old browser
  # (or nothing at all, once that path is collected) until the next logout.
  # home.packages above is what puts it on PATH.
  home.sessionVariables.BROWSER = "vivaldi";
}
