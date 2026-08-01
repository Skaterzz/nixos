{ config, lib, pkgs, inputs, ... }:

let
  user        = "joshr";
  greeter     = "plasmalogin";
  greeterHome = "/var/lib/plasmalogin";   # PLM greeter user's home (STATE_DIR)
  wallpaper = "${inputs.dotfiles}/dot_local/share/wallpapers/Anime/Yor.jpg";

  # Exactly the set PLM's "Apply Plasma Settings" syncs into the greeter.
  files = [ "kxkbrc" "kdeglobals" "plasmarc" "kcminputrc" "kwinoutputconfig.json" ];

  syncScript = pkgs.writeShellScript "plasmalogin-sync" ''
    set -eu
    src=/home/${user}/.config
    dst=${greeterHome}/.config
    ${pkgs.coreutils}/bin/install -d -o ${greeter} -g ${greeter} -m 0750 "$dst"

    for f in ${lib.concatStringsSep " " files}; do
      if [ -f "$src/$f" ]; then
        ${pkgs.coreutils}/bin/install -Dm600 -o ${greeter} -g ${greeter} "$src/$f" "$dst/$f"
      fi
    done
    if [ -f "$src/fontconfig/fonts.conf" ]; then
      ${pkgs.coreutils}/bin/install -Dm600 -o ${greeter} -g ${greeter} \
        "$src/fontconfig/fonts.conf" "$dst/fontconfig/fonts.conf"
    fi

    # PLM wipes the greeter cache on every apply so theme/colour changes take.
    ${pkgs.coreutils}/bin/rm -rf ${greeterHome}/.cache
  '';
in
{
  # Optional on Wayland, but harmless — and it still feeds the greeter's
  # default keyboard layout via services.xserver.xkb.*.
  services.xserver.enable = true;

  services.displayManager.plasma-login-manager.enable = true;

  services.displayManager.plasma-login-manager.settings = {
    Greeter.WallpaperPluginId = "org.kde.image";            # default image plugin
    "Greeter][Wallpaper][org.kde.image][General".Image = "file://${wallpaper}";
  };

  services.desktopManager.plasma6.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };

  # Audio for Spotify/Discord/Steam/games.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };

  services.flatpak.enable = true;

  # Mirror joshr's Plasma display/theme/input config into the PLM greeter.
  systemd.services.plasmalogin-sync = {
    description = "Mirror ${user}'s Plasma config to the Plasma Login greeter";
    wantedBy = [ "multi-user.target" ];   # seed once at boot
    serviceConfig = {
      Type = "oneshot";
      ExecStart = syncScript;
    };
  };

  # Re-run whenever KWin rewrites the layout or input config.
  systemd.paths.plasmalogin-sync = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = [
      "/home/${user}/.config/kwinoutputconfig.json"
      "/home/${user}/.config/kcminputrc"
    ];
  };
}
