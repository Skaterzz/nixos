{ config, lib, pkgs, niriTheming, ... }:

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
    ./openrgb.nix
    #./firefox.nix
  ];

  # Dolphin as the graphical file manager. It follows the active theme
  # through kdeglobals — see the symlink below.
  home.packages = with pkgs; [
    kdePackages.dolphin
    kdePackages.kio-fuse # mount remote filesystems in place
    kdePackages.kio-extras # sftp://, mtp://, trash:// and friends
    kdePackages.qtsvg # icon rendering
    kdePackages.breeze-icons # fallback icons Dolphin expects to exist

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

  # Cursor theme is set in ../home.nix so the Plasma and niri sessions share
  # one definition; niri.nix just names it in `cursor { xcursor-theme … }`.

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

  # Point KDE apps at the active theme's kdeglobals.
  #
  # KColorScheme reads this whether or not Plasma is running, so Dolphin
  # picks up the palette in a bare niri session. It has to be a symlink to
  # the mutable state path rather than a store file, or a theme switch
  # couldn't change it — mkOutOfStoreSymlink is home-manager's escape hatch
  # for exactly that.
  #
  # Dolphin reads this at startup, so a running window keeps its old colours
  # until relaunched.
  xdg.configFile."kdeglobals".source =
    config.lib.file.mkOutOfStoreSymlink "${niriTheming.activeDir}/kdeglobals";

  # Point kitty at the active theme's colours.
  #
  # This lives here rather than in ../kitty.nix because that module is shared
  # with the Plasma hosts, which have no niri theme state — the include would
  # be a dangling path there. On a niri host it's appended to everything
  # kitty.nix already set, and kitty takes the last value for any key, so the
  # colours are overridden and font, padding and opacity are left alone.
  #
  # mkAfter is what guarantees that ordering: extraConfig is a `lines` option,
  # and without it the merge order between two modules isn't defined.
  #
  # The theme switcher reloads running terminals; see scripts.nix.
  programs.kitty.extraConfig = lib.mkAfter ''

    include ${niriTheming.activeDir}/kitty.conf
  '';
}
