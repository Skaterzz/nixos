{ pkgs, ... }:

# OBS follows the live Noctalia palette through the community "Matugen"
# theme.
#
# What this replaces
# ------------------
# OBS used to be themed the long way round: a `NiriIcons.ovt` child theme
# extending OBS's bundled `com.obsproject.System`, which takes its colours
# from the Qt palette, which came from `~/.config/kdeglobals`, which is a
# symlink into whichever theme directory was active. Three indirections to
# arrive at a palette OBS was only ever *inferring*, and the .ovt existed
# solely to undo one consequence of it — System hard-codes dark toolbar and
# source icons, so a light palette came out with invisible glyphs.
#
# `matugen.obt` is a complete OBS theme rather than a palette OBS has to
# guess at, and it is one of the templates Noctalia renders directly from its
# colour roles (`obs` in `community_ids`, see niri/noctalia.nix). So the whole
# chain collapses to: Noctalia writes the theme, OBS is told to use it.
#
# The theme file lands at ~/.config/obs-studio/themes/matugen.obt on every
# colour-scheme change. Before Noctalia has run once — a fresh machine — it
# isn't there yet and OBS falls back to its own default theme, which is the
# right failure: a themeless OBS rather than an unstyled one.
let
  obsWithCuda = pkgs.obs-studio.override {
    cudaSupport = true;
  };

  # From the `@OBSThemeMeta` block of the community template's matugen.obt.
  # OBS matches on this id, not on the file name or the display name.
  obsThemeId = "com.obsproject.matugen";

  obsThemed = pkgs.writeShellApplication {
    name = "obs-themed";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.perl
    ];

    text = ''
      config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
      config="$config_home/obs-studio/user.ini"

      mkdir -p "$(dirname "$config")"
      touch "$config"

      ${pkgs.perl}/bin/perl -0pi -e '
        s/^[ \t]*Theme[ \t]*=.*(?:\n|\z)//mg;

        if (/^\[Appearance\][ \t]*$/m) {
          s/^(\[Appearance\][ \t]*\n)/$1Theme=${obsThemeId}\n/m;
        } else {
          $_ .= "\n[Appearance]\nTheme=${obsThemeId}\n";
        }
      ' "$config"

      # Out of the way of the theme.
      #
      # These two used to be *set* here, to `kde` and `breeze`, because the
      # System theme's whole job was to inherit the KDE palette. A complete
      # .obt brings its own palette and its own widget styling, so leaving the
      # session's KDE platform theme in place now means Breeze drawing
      # controls underneath colours it knows nothing about. Unsetting rather
      # than assigning something else leaves OBS on the platform default it is
      # developed against.
      unset QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE

      exec ${obsWithCuda}/bin/obs "$@"
    '';
  };
in
{
  home.packages = [
    obsWithCuda
    obsThemed
  ];

  # Override the upstream launcher at Home Manager priority so launchers
  # always select the Matugen theme before starting OBS.
  xdg.desktopEntries."com.obsproject.Studio" = {
    name = "OBS Studio";
    genericName = "Streaming and Recording Software";
    comment = "Free and open source software for video recording and live streaming";
    exec = "${obsThemed}/bin/obs-themed %U";
    icon = "com.obsproject.Studio";
    terminal = false;
    startupNotify = true;

    categories = [
      "AudioVideo"
      "Recorder"
    ];

    settings = {
      StartupWMClass = "obs";
      DBusActivatable = "false";
    };
  };
}
