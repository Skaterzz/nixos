{ config, pkgs, ... }:

# OBS follows the active niri/KDE Qt palette through OBS's bundled System
# theme. A small child theme keeps that palette but replaces System's
# hard-coded dark toolbar/settings/source icons with OBS's own light assets.
let
  obsWithCuda = pkgs.obs-studio.override {
    cudaSupport = true;
  };

  obsThemeId = "com.${config.home.username}.NiriSystem";

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

      export QT_QPA_PLATFORMTHEME=kde
      export QT_STYLE_OVERRIDE=breeze

      exec ${obsWithCuda}/bin/obs "$@"
    '';
  };
in
{
  home.packages = [
    obsWithCuda
    obsThemed
  ];
}
