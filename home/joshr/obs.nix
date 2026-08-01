{ pkgs, ... }:

# OBS follows the active niri/KDE Qt palette through OBS's bundled System
# theme. A small child theme keeps that palette but replaces System's
# hard-coded dark toolbar/settings/source icons with OBS's own light assets.
let
  obsThemeId = "com.joshr.NiriSystem";

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

      # OBS can leave duplicate Theme keys with different spacing. Remove all
      # of them, then insert exactly one deterministic value.
      ${pkgs.perl}/bin/perl -0pi -e '
        s/^[ \t]*Theme[ \t]*=.*(?:\n|\z)//mg;

        if (/^\[Appearance\][ \t]*$/m) {
          s/^(\[Appearance\][ \t]*\n)/$1Theme=${obsThemeId}\n/m;
        } else {
          $_ .= "\n[Appearance]\nTheme=${obsThemeId}\n";
        }
      ' "$config"

      # The System parent theme reads the active Qt/KDE palette.
      export QT_QPA_PLATFORMTHEME=kde
      export QT_STYLE_OVERRIDE=breeze

      exec ${pkgs.obs-studio}/bin/obs "$@"
    '';
  };
in
{
  home.packages = [
    pkgs.obs-studio
    obsThemed
  ];

  # OBS custom themes live under ~/.config/obs-studio/themes on Linux.
  # This is a variant, not a complete theme: all colours and widget styling
  # continue to come from com.obsproject.System.
  xdg.configFile."obs-studio/themes/NiriIcons.ovt".text = ''
    @OBSThemeMeta {
        name: 'Niri System';
        id: '${obsThemeId}';
        extends: 'com.obsproject.System';
        author: 'Josh Randall';
        dark: 'true';
    }

    /* Main toolbar/list buttons */
    .icon-plus {
        qproperty-icon: url(theme:Dark/plus.svg);
    }

    .icon-minus {
        qproperty-icon: url(theme:Dark/minus.svg);
    }

    .icon-trash {
        qproperty-icon: url(theme:Dark/trash.svg);
    }

    .icon-clear {
        qproperty-icon: url(theme:Dark/entry-clear.svg);
    }

    .icon-gear {
        qproperty-icon: url(theme:Dark/settings/general.svg);
    }

    .icon-dots-vert {
        qproperty-icon: url(theme:Dark/dots-vert.svg);
    }

    .icon-refresh {
        qproperty-icon: url(theme:Dark/refresh.svg);
    }

    .icon-cogs {
        qproperty-icon: url(theme:Dark/cogs.svg);
    }

    .icon-touch {
        qproperty-icon: url(theme:Dark/interact.svg);
    }

    .icon-up {
        qproperty-icon: url(theme:Dark/up.svg);
    }

    .icon-down {
        qproperty-icon: url(theme:Dark/down.svg);
    }

    .icon-pause {
        qproperty-icon: url(theme:Dark/media-pause.svg);
    }

    .icon-filter {
        qproperty-icon: url(theme:Dark/filter.svg);
    }

    .icon-revert {
        qproperty-icon: url(theme:Dark/revert.svg);
    }

    .icon-save {
        qproperty-icon: url(theme:Dark/save.svg);
    }

    .icon-close {
        qproperty-icon: url(theme:Dark/close.svg);
    }

    .icon-pin {
        qproperty-icon: url(theme:Dark/pin.svg);
    }

    .icon-layout-vertical {
        qproperty-icon: url(theme:Dark/layout-vertical.svg);
    }

    .icon-layout-horizontal {
        qproperty-icon: url(theme:Dark/layout-horizontal.svg);
    }

    /* Settings sidebar */
    OBSBasicSettings {
        qproperty-generalIcon: url(theme:Dark/settings/general.svg);
        qproperty-appearanceIcon: url(theme:Dark/settings/appearance.svg);
        qproperty-streamIcon: url(theme:Dark/settings/stream.svg);
        qproperty-outputIcon: url(theme:Dark/settings/output.svg);
        qproperty-audioIcon: url(theme:Dark/settings/audio.svg);
        qproperty-videoIcon: url(theme:Dark/settings/video.svg);
        qproperty-hotkeysIcon: url(theme:Dark/settings/hotkeys.svg);
        qproperty-accessibilityIcon: url(theme:Dark/settings/accessibility.svg);
        qproperty-advancedIcon: url(theme:Dark/settings/advanced.svg);
    }

    /* Sources dock */
    OBSBasic {
        qproperty-imageIcon: url(theme:Dark/sources/image.svg);
        qproperty-colorIcon: url(theme:Dark/sources/brush.svg);
        qproperty-slideshowIcon: url(theme:Dark/sources/slideshow.svg);
        qproperty-audioInputIcon: url(theme:Dark/sources/microphone.svg);
        qproperty-audioOutputIcon: url(theme:Dark/settings/audio.svg);
        qproperty-desktopCapIcon: url(theme:Dark/settings/video.svg);
        qproperty-windowCapIcon: url(theme:Dark/sources/window.svg);
        qproperty-gameCapIcon: url(theme:Dark/sources/gamepad.svg);
        qproperty-cameraIcon: url(theme:Dark/sources/camera.svg);
        qproperty-textIcon: url(theme:Dark/sources/text.svg);
        qproperty-mediaIcon: url(theme:Dark/sources/media.svg);
        qproperty-browserIcon: url(theme:Dark/sources/globe.svg);
        qproperty-groupIcon: url(theme:Dark/sources/group.svg);
        qproperty-sceneIcon: url(theme:Dark/sources/scene.svg);
        qproperty-defaultIcon: url(theme:Dark/sources/default.svg);
        qproperty-audioProcessOutputIcon: url(theme:Dark/sources/windowaudio.svg);
    }

    /* Tree/list state icons */
    .indicator-lock::indicator:checked,
    .indicator-lock::indicator:checked:hover {
        image: url(theme:Dark/locked.svg);
    }

    .indicator-visibility::indicator:checked,
    .indicator-visibility::indicator:checked:hover {
        image: url(theme:Dark/visible.svg);
    }

    .indicator-expand::indicator:checked,
    .indicator-expand::indicator:checked:hover {
        image: url(theme:Dark/expand.svg);
    }

    .indicator-expand::indicator:unchecked,
    .indicator-expand::indicator:unchecked:hover {
        image: url(theme:Dark/collapse.svg);
    }

    OBSYoutubeActions {
        qproperty-thumbPlaceholder: url(theme:Dark/sources/image.svg);
    }
  '';

  # Override the upstream launcher at Home Manager priority so launchers
  # always set the custom System-derived variant before starting OBS.
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
