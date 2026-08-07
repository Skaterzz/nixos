{ config, lib, pkgs, ... }:

# Graphical applications used by the gamestation-niri Home Manager profile.
#
# The applications used to live in modules/nixos/desktop-apps.nix as system
# packages. Keeping them in the user's profile gives KDE/KService one coherent
# XDG_DATA_DIRS entry and lets Home Manager own the media desktop entries and
# MIME defaults alongside the packages they launch.
let
  imageMimes = [
    "image/jpeg"
    "image/png"
    "image/gif"
    "image/webp"
    "image/tiff"
    "image/bmp"
    "image/avif"
    "image/heif"
    "image/heic"
    "image/svg+xml"
    "image/x-icon"
  ];

  videoMimes = [
    "video/mp4"
    "video/mpeg"
    "video/quicktime"
    "video/x-msvideo"
    "video/x-matroska"
    "video/webm"
    "video/ogg"
    "video/x-flv"
    "video/3gpp"
    "video/3gpp2"
  ];

  audioMimes = [
    "audio/mpeg"
    "audio/wav"
    "audio/x-wav"
    "audio/flac"
    "audio/x-flac"
    "audio/ogg"
    "audio/x-vorbis+ogg"
    "audio/aac"
    "audio/mp4"
    "audio/x-m4a"
    "audio/opus"
    "audio/x-opus+ogg"
  ];

  # Prefix for this profile's private desktop entries — see xdg.desktopEntries
  # below. Each one is written to ~/.local/share/applications/<id>.desktop, so
  # the id is a filename: taking it from `config.home.username` rather than
  # writing "joshr" keeps it the account's own on every profile that imports
  # this file, home/raiden/ included. It resolves to "joshr" here, so the
  # entries and the mimeapps.list pointing at them are unchanged.
  entryPrefix = config.home.username;

  mediaDefaults =
    lib.genAttrs imageMimes (_: "${entryPrefix}-gwenview.desktop")
    // lib.genAttrs videoMimes (_: "${entryPrefix}-haruna.desktop")
    // lib.genAttrs audioMimes (_: "${entryPrefix}-elisa.desktop");

  # KService requires a valid XDG menu before it will index desktop entries.
  # Plasma normally provides plasma-applications.menu and sets
  # XDG_MENU_PREFIX=plasma-. A standalone niri session does neither, so keep a
  # small menu in the user's XDG config. Both names are provided so the cache
  # works before and after the session variable is imported.
  applicationsMenu = pkgs.writeText "applications.menu" ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <DefaultMergeDirs/>
      <Include>
        <All/>
      </Include>
    </Menu>
  '';
in
{
  home.packages = with pkgs; [
    discord
    papirus-icon-theme
    signal-desktop
    joplin-desktop
    bitwarden-desktop
    nextcloud-client
    localsend
    playerctl
    cava
    cmatrix
    haruna
    kdePackages.gwenview
    kdePackages.elisa
    termius
    kdePackages.kcalc
    thunderbird
    kdePackages.kate
    vesktop

    # Provides kbuildsycoca6, KDE's desktop-entry and MIME service cache.
    kdePackages.kservice

    kdePackages.kimageformats

    qjackctl
  ];

 home.activation.modifyNextcloudConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
  CONFIG_DIR="$HOME/.config/Nextcloud"
  CONFIG_FILE="''${CONFIG_DIR}/nextcloud.cfg"

  if [ -f "''${CONFIG_FILE}" ]; then
    # Escape the Nix interpolation by using two single quotes before the bash variable
    if ! grep -q "showExperimentalOptions" "''${CONFIG_FILE}"; then
      if grep -q "\[General\]" "''${CONFIG_FILE}"; then
        sed -i '/\[General\]/a showExperimentalOptions=true' "''${CONFIG_FILE}"
      else
        echo -e "\n[General]\nshowExperimentalOptions=true" >> "''${CONFIG_FILE}"
      fi
    fi
  else
    mkdir -p "''${CONFIG_DIR}"
    echo -e "[General]\nshowExperimentalOptions=true" > "''${CONFIG_FILE}"
  fi
'';
  # Make both shells and systemd/D-Bus activated user services agree about the
  # menu name KDE should load.
  home.sessionVariables.XDG_MENU_PREFIX = "plasma-";
  systemd.user.sessionVariables.XDG_MENU_PREFIX = "plasma-";

  xdg.configFile = {
    "menus/applications.menu".source = applicationsMenu;
    "menus/plasma-applications.menu".source = applicationsMenu;

    # Home Manager intentionally owns the MIME defaults for this profile.
    "mimeapps.list".force = true;
  };

  # # Use private entry IDs rather than overriding KDE's upstream files. This
  # # avoids D-Bus activation metadata and launches the exact Nix-store binary.
  # xdg.desktopEntries = {
  #   "${entryPrefix}-gwenview" = {
  #     name = "Gwenview";
  #     genericName = "Image Viewer";
  #     comment = "Open images with Gwenview";
  #     exec = "${pkgs.kdePackages.gwenview}/bin/gwenview %U";
  #     icon = "gwenview";
  #     terminal = false;
  #     categories = [
  #       "Graphics"
  #       "Viewer"
  #     ];
  #     mimeType = imageMimes;
  #     settings.DBusActivatable = "false";
  #   };

  #   "${entryPrefix}-haruna" = {
  #     name = "Haruna";
  #     genericName = "Video Player";
  #     comment = "Open videos with Haruna";
  #     exec = "${pkgs.haruna}/bin/haruna %U";
  #     icon = "haruna";
  #     terminal = false;
  #     categories = [
  #       "AudioVideo"
  #       "Video"
  #       "Player"
  #     ];
  #     mimeType = videoMimes;
  #     settings.DBusActivatable = "false";
  #   };

  #   "${entryPrefix}-elisa" = {
  #     name = "Elisa";
  #     genericName = "Music Player";
  #     comment = "Open audio with Elisa";
  #     exec = "${pkgs.kdePackages.elisa}/bin/elisa %U";
  #     icon = "elisa";
  #     terminal = false;
  #     categories = [
  #       "AudioVideo"
  #       "Audio"
  #       "Player"
  #     ];
  #     mimeType = audioMimes;
  #     settings.DBusActivatable = "false";
  #   };
  # };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = mediaDefaults;
    associations.added = mediaDefaults;
  };

  # Rebuild KDE's service database after Home Manager links the packages,
  # desktop entries, menu definition, and mimeapps.list into the new profile.
  home.activation.rebuildKdeServiceCache =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      export XDG_MENU_PREFIX=plasma-
      rm -f "$HOME"/.cache/ksycoca6_*
      ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental
    '';
}
