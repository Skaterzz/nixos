{ lib, pkgs, ... }:

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

  defaults =
    lib.genAttrs imageMimes (_: "org.kde.gwenview.desktop")
    // lib.genAttrs videoMimes (_: "org.kde.haruna.desktop")
    // lib.genAttrs audioMimes (_: "org.kde.elisa.desktop");
in
{
  xdg.configFile."mimeapps.list".force = true;

  # Override the upstream desktop entries at user priority.
  #
  # Absolute executable paths remove PATH ambiguity, and explicitly disabling
  # D-Bus activation makes KDE launch the process directly with Dolphin's
  # working niri/Wayland environment.
  # xdg.desktopEntries = {
  #   "org.kde.gwenview" = {
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

  #   "org.kde.haruna" = {
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

  #   "org.kde.elisa" = {
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

  # xdg.mimeApps = {
  #   enable = true;

  #   defaultApplications = defaults;

  #   # Also explicitly advertise these entries as MIME handlers to KDE's
  #   # application trader, rather than relying solely on the desktop files.
  #   associations.added = defaults;
  # };

  # Dolphin reads KDE's KSycoca application database. Rebuild it after Home
  # Manager links the new desktop entries into ~/.local/share/applications.
  home.activation.rebuildKdeServiceCache =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental
    '';
}