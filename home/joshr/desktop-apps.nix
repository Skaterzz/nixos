{ lib, pkgs, ... }:

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

  mediaDefaults =
    lib.genAttrs imageMimes (_: "joshr-gwenview.desktop")
    // lib.genAttrs videoMimes (_: "joshr-haruna.desktop")
    // lib.genAttrs audioMimes (_: "joshr-elisa.desktop");

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
    obs-studio
    lutris
    localsend
    playerctl
    cava
    cmatrix
    yt-dlp
    haruna
    kdePackages.gwenview
    kdePackages.elisa
    termius
    kdePackages.kcalc
    thunderbird
    kdePackages.kate

    # Provides kbuildsycoca6, KDE's desktop-entry and MIME service cache.
    kdePackages.kservice
  ];

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

  # Use private entry IDs rather than overriding KDE's upstream files. This
  # avoids D-Bus activation metadata and launches the exact Nix-store binary.
  xdg.desktopEntries = {
    "joshr-gwenview" = {
      name = "Gwenview";
      genericName = "Image Viewer";
      comment = "Open images with Gwenview";
      exec = "${pkgs.kdePackages.gwenview}/bin/gwenview %U";
      icon = "gwenview";
      terminal = false;
      categories = [
        "Graphics"
        "Viewer"
      ];
      mimeType = imageMimes;
      settings.DBusActivatable = "false";
    };

    "joshr-haruna" = {
      name = "Haruna";
      genericName = "Video Player";
      comment = "Open videos with Haruna";
      exec = "${pkgs.haruna}/bin/haruna %U";
      icon = "haruna";
      terminal = false;
      categories = [
        "AudioVideo"
        "Video"
        "Player"
      ];
      mimeType = videoMimes;
      settings.DBusActivatable = "false";
    };

    "joshr-elisa" = {
      name = "Elisa";
      genericName = "Music Player";
      comment = "Open audio with Elisa";
      exec = "${pkgs.kdePackages.elisa}/bin/elisa %U";
      icon = "elisa";
      terminal = false;
      categories = [
        "AudioVideo"
        "Audio"
        "Player"
      ];
      mimeType = audioMimes;
      settings.DBusActivatable = "false";
    };
  };

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
