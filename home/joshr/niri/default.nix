{ config, lib, pkgs, ... }:

# niri desktop for joshr: compositor config, bar, notifications, launcher,
# lock screen, and the theme/wallpaper switcher.
#
# Import order matters a little: theming.nix and scripts.nix publish
# `_module.args` (niriTheming, niriScripts) that the others consume.
{
  imports = [
    ./theming.nix
    ./scripts.nix
    ./niri.nix
    ./waybar.nix
    ./notifications.nix
    ./lock.nix
  ];

  home.packages = with pkgs; [
    # Screenshot stack: grim captures, slurp selects, satty annotates.
    grim
    slurp
    satty

    # Wallpaper daemon (this is swww — renamed to awww in nixpkgs 2026-03).
    awww

    # Clipboard, brightness, media control for the keybinds above.
    wl-clipboard
    brightnessctl
    playerctl

    # Tray applet for NetworkManager, spawned at startup.
    networkmanagerapplet

    # X11 apps under niri.
    xwayland-satellite
  ];

  # Cursor theme, applied to both GTK and the compositor.
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Noto Sans";
      size = 10;
    };
  };

  # Dark preference for apps that honour it (GTK4/libadwaita, Electron).
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
