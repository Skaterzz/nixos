{ pkgs, ... }:

# OBS Studio follows the active niri/KDE palette through OBS's hidden System
# theme. The wrapper changes only the Appearance/Theme key in OBS's mutable
# user.ini before launch; scenes, profiles, outputs, and every other setting
# remain owned by OBS.
let
  obsThemed = pkgs.writeShellApplication {
    name = "obs-themed";

    runtimeInputs = [ pkgs.crudini ];

    text = ''
      config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
      config="$config_home/obs-studio/user.ini"

      mkdir -p "$(dirname "$config")"

      # OBS 31+ stores user-facing settings in user.ini. System is a bundled
      # but hidden theme whose intentionally sparse stylesheet lets Qt's
      # current palette show through.
      crudini --set "$config" Appearance Theme com.obsproject.System

      # Be explicit for launches from application menus and systemd/D-Bus,
      # which do not always inherit every interactive shell variable.
      export QT_QPA_PLATFORMTHEME=kde

      exec ${pkgs.obs-studio}/bin/obs "$@"
    '';
  };
in
{
  home.packages = [
    pkgs.obs-studio
    obsThemed
  ];

  # Override OBS's upstream launcher at user-profile priority so wofi and other
  # launchers always go through obs-themed. The executable remains named `obs`
  # inside the wrapper, so plugins and OBS's own paths behave normally.
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
