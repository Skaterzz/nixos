{ lib, ... }:

# Media defaults for the niri gamestation profile.
#
# This intentionally uses Home Manager's `xdg.mimeApps` rather than relying
# only on the lower-priority /etc/xdg baseline in modules/nixos/default-apps.nix.
# Home Manager owns ~/.config/mimeapps.list as a read-only store symlink, so
# Dolphin and other desktop tools cannot silently replace these associations.
let
  gwenview = [
    "org.kde.gwenview.desktop"
    "gwenview.desktop"
  ];

  haruna = [
    "org.kde.haruna.desktop"
    "haruna.desktop"
  ];

  elisa = [
    "org.kde.elisa.desktop"
    "elisa.desktop"
  ];

  defaults =
    lib.genAttrs
      [
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
      ]
      (_: gwenview)
    // lib.genAttrs
      [
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
      ]
      (_: haruna)
    // lib.genAttrs
      [
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
      ]
      (_: elisa);
in
{
  # Always replace any existing user-managed MIME configuration.
  xdg.configFile."mimeapps.list".force = true;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = defaults;
  };
}
