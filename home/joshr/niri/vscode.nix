{ config, lib, niriTheming, ... }:

# The niri half of VS Code: make the editor wear the active palette.
#
# Why an extension
# ----------------
# VS Code has no "read colours from this path" setting. A colour theme is
# only ever contributed by an extension, and `workbench.colorTheme` names it
# by label. So theming.nix renders a complete one-theme extension per palette
# and this drops the whole directory into the extensions folder as an
# out-of-store symlink — the same trick as kdeglobals and Firefox's
# userChrome.css, one directory up.
#
# `workbench.colorTheme` therefore stays "Niri" forever: switching palettes
# re-points the symlink at a different build of the same extension, so the
# name in settings.json never has to change. That matters because settings
# .json is written by home-manager into the store and cannot be edited at
# runtime, which is exactly why the colours can't live there.
#
# The directory name is `<publisher>.<name>-<version>`, matching what
# home-manager's own `programs.vscode.….extensions` writes. VS Code scans the
# extensions folder and reads each child's package.json; that convention is
# what every Nix-installed extension already relies on.
#
# This is separate from ../vscode.nix — which configures the editor itself
# and is shared with the Plasma hosts — for the same reason ./firefox.nix is
# separate from ../firefox.nix: the Plasma hosts have no niri theme state, so
# `${niriTheming.activeDir}` doesn't exist there and the symlink would dangle.
#
# VS Code reads extensions once, while it starts. A theme switch lands the
# next time the editor starts, like Dolphin and Firefox and unlike kitty or
# waybar, which the switcher can nudge.
{
  home.file.".vscode/extensions/niri.niri-theme-1.0.0".source =
    config.lib.file.mkOutOfStoreSymlink "${niriTheming.activeDir}/vscode-extension";

  programs.vscode.profiles.default.userSettings = {
    # mkForce because ../vscode.nix sets this too — that is the value the
    # Plasma hosts keep, and it is a marketplace theme this one replaces.
    "workbench.colorTheme" = lib.mkForce "Niri";

    # Off, or VS Code overrides the theme above with
    # preferredLight/DarkColorTheme whenever the OS reports a colour scheme.
    # Several palettes here are light, so "follow the system" would fight the
    # switcher rather than agree with it.
    "window.autoDetectColorScheme" = false;
  };
}
