{ config, lib, pkgs, ... }:

# System side of the niri desktop: the session itself, the display manager,
# and the bits home-manager can't write (PAM, polkit, system services).
#
# This replaces modules/nixos/desktop.nix on a host — importing both would
# enable two desktop sessions and two display managers.
let
  themeSet = import ../../home/joshr/niri/themes.nix { inherit lib; };
  inherit (themeSet) themes;

  # The palette renderer lives with the home modules so both sides agree on
  # the colours. Only the SDDM part is needed here.
  # The user's current wallpaper, copied somewhere the greeter can read it.
  # See sddm-theme-sync below — the path is fixed so the theme config can name
  # it from the store while the image behind it changes at runtime.
  sddmWallpaper = "/var/lib/sddm-theme/wallpaper.png";

  sddmThemeConfig =
    t:
    {
      # --- background ---------------------------------------------------
      # The wallpaper should be visible, so the dim is light and the blur is
      # gentle. PartialBlur keeps the blur to the strip behind the form and
      # drops that panel to 0.3 opacity, so the picture reads through there
      # too; FullBlur would fog the whole screen.
      Background = "file://${sddmWallpaper}";
      CropBackground = "true";
      BackgroundHorizontalAlignment = "center";
      BackgroundVerticalAlignment = "center";
      FullBlur = "false";
      PartialBlur = "true";
      Blur = "1.4";
      BlurMax = "32";
      DimBackground = "0.2";

      # --- form ---------------------------------------------------------
      # Clock and login sit in a column on the right, leaving the rest of the
      # wallpaper clear. Still vertically centred — the theme has no vertical
      # position setting, so moving it lower would need a QML patch.
      HaveFormBackground = "true";
      FormPosition = "right";
      RoundCorners = "24";
      ScreenPadding = "0";

      # Land on the password field for the last user; no username step.
      ForceLastUser = "true";
      PasswordFocus = "true";
      UseRealName = "true";
      HideCompletePassword = "true";
      HideVirtualKeyboard = "true";
      HideSystemButtons = "false";

      # The clock is the header; a "Welcome" string on top of it is noise.
      HeaderText = "";
      HourFormat = "HH:mm";
      DateFormat = "dddd, d MMMM";

      HeaderTextColor = t.accent;
      DateTextColor = t.fg;
      TimeTextColor = t.accent;
      FormBackgroundColor = t.bg;
      BackgroundColor = t.bg;
      DimBackgroundColor = "#000000";
      LoginFieldBackgroundColor = t.bgAlt;
      PasswordFieldBackgroundColor = t.bgAlt;
      LoginFieldTextColor = t.fg;
      PasswordFieldTextColor = t.fg;
      UserIconColor = t.accent;
      PasswordIconColor = t.accent;
      PlaceholderTextColor = t.fgDim;
      WarningColor = t.err;
      LoginButtonTextColor = t.bg;
      LoginButtonBackgroundColor = t.accent;
      SystemButtonsIconsColor = t.accent;
      SessionButtonTextColor = t.fg;
      VirtualKeyboardButtonTextColor = t.fg;
      DropdownTextColor = t.fg;
      DropdownSelectedBackgroundColor = t.accentDim;
      DropdownBackgroundColor = t.bgAlt;
      HighlightTextColor = t.bg;
      HighlightBackgroundColor = t.accent;
      HighlightBorderColor = t.accent;
      HoverUserIconColor = t.fg;
      HoverSystemButtonsIconsColor = t.fg;

      Font = "Poppins";
      FontSize = "12";
    };

  # One sddm-astronaut instance per palette. They're cheap — the derivation
  # only copies the upstream theme and writes a .conf — and having all of
  # them installed is what lets the greeter follow a runtime theme switch
  # without a rebuild.
  #
  # Each is renamed so the themes don't collide in the SDDM theme directory.
  mkSddmTheme =
    name: t:
    (pkgs.sddm-astronaut.override {
      embeddedTheme = "black_hole";
      themeConfig = sddmThemeConfig t;
    }).overrideAttrs
      (old: {
        pname = "sddm-astronaut-${name}";
        postInstall = (old.postInstall or "") + ''
          themeDir="$out/share/sddm/themes/sddm-astronaut-theme"
          chmod -R u+w "$themeDir"

          # Force the password field to mask immediately.
          #
          # Upstream binds passwordMaskDelay to `undefined` when
          # HideCompletePassword is "true", which doesn't mean "no delay" — it
          # drops the binding back to Qt's platform default, so how long a
          # typed character stays visible depends on the platform and on the
          # theme config being parsed exactly as the QML expects. That is a
          # bad thing to leave to chance on a login screen.
          #
          # 0 is unambiguous: characters are replaced the instant they're
          # typed, regardless of any config value.
          substituteInPlace "$themeDir/Components/Input.qml" \
            --replace-fail \
              'passwordMaskDelay: config.HideCompletePassword == "true" ? undefined : 1000' \
              'passwordMaskDelay: 0'

          mv "$themeDir" "$out/share/sddm/themes/niri-${name}"
        '';
      });

  sddmThemes = lib.mapAttrs mkSddmTheme themes;

  defaultSddmTheme = "niri-${themeSet.default}";

  # Watches the user's theme *and* wallpaper choices and mirrors both to the
  # login screen. SDDM only reads its config when the greeter starts, so both
  # take effect at the next logout/reboot rather than immediately.
  niriStateDir = "/home/joshr/.local/state/niri-theme";
  themeStateFile = "${niriStateDir}/current";
  wallpaperStateFile = "${niriStateDir}/wallpaper";

  syncSddmTheme = pkgs.writeShellScript "sddm-theme-sync" ''
    set -eu

    # --- palette ------------------------------------------------------
    name="$(cat ${themeStateFile} 2>/dev/null || true)"
    case "$name" in
    ${lib.concatStringsSep "\n" (map (n: "      ${n}) ;;") (lib.attrNames themes))}
      *) name="${themeSet.default}" ;;
    esac

    mkdir -p /etc/sddm.conf.d
    printf '[Theme]\nCurrent=niri-%s\n' "$name" \
      > /etc/sddm.conf.d/99-niri-active-theme.conf

    # --- wallpaper ----------------------------------------------------
    # The greeter runs as the sddm user and can't read joshr's home, so the
    # image is copied somewhere world-readable. The theme config names a
    # fixed path (see sddmWallpaper), and only the file behind it changes.
    #
    # Converted to PNG rather than copied: the state file may point at a
    # .jpg, and naming a JPEG "wallpaper.png" leaves the format to QML's
    # content sniffing. Converting removes the guess.
    install -d -m 0755 /var/lib/sddm-theme

    wp="$(cat ${wallpaperStateFile} 2>/dev/null || true)"
    if [ -n "$wp" ] && [ -f "$wp" ]; then
      tmp="${sddmWallpaper}.tmp"
      if ${pkgs.imagemagick}/bin/magick "$wp" -strip "png:$tmp" 2>/dev/null; then
        mv -f "$tmp" "${sddmWallpaper}"
        chmod 0644 "${sddmWallpaper}"
      else
        # Leave the previous image in place rather than blanking the
        # greeter over one unreadable file.
        rm -f "$tmp"
      fi
    fi
  '';
in
{
  programs.niri.enable = true;

  # Display manager. SDDM's Wayland greeter is what niri wants; the X11
  # greeter would start an X server just to draw the login screen.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    theme = defaultSddmTheme;
    extraPackages = lib.attrValues sddmThemes;
  };

  # Every themed variant must be on the system so the greeter can switch
  # between them without a rebuild.
  environment.systemPackages = lib.attrValues sddmThemes;

  # --- keep the login screen in step with the desktop ---------------------
  #
  # Two things are mirrored: the palette (which of the per-theme SDDM packages
  # to use) and the wallpaper (copied to a world-readable path the theme names
  # from the store).
  #
  # The greeter runs as the sddm user before anyone logs in, so it can neither
  # read joshr's home nor see the theme symlink, and /etc is store-managed.
  # This writes one unmanaged drop-in under /etc/sddm.conf.d/ — NixOS only
  # removes files it declares, so it survives activation.
  systemd.services.sddm-theme-sync = {
    description = "Mirror the desktop theme and wallpaper to the SDDM greeter";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = syncSddmTheme;
    };
  };

  systemd.paths.sddm-theme-sync = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = [
      themeStateFile
      wallpaperStateFile
    ];
  };

  # swaylock authenticates through PAM and ships no entry of its own, so
  # without this the lock screen accepts a password and then refuses it —
  # you get locked out of your own session. An empty attrset is enough; it
  # just needs the /etc/pam.d file to exist.
  security.pam.services.swaylock = { };

  # A polkit agent must run in the session for GUI privilege prompts. niri
  # doesn't ship one, so start the KDE agent as a user service tied to the
  # graphical session.
  security.polkit.enable = true;
  systemd.user.services.polkit-kde-agent = {
    description = "polkit KDE agent";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # Audio. Same stack as the Plasma config.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Screen sharing needs a portal backend; the niri module already pulls in
  # xdg-desktop-portal-gnome and sets the routing.
  xdg.portal.enable = true;

  services.flatpak.enable = true;

  # Mount/unmount removable media from the file manager without a password.
  services.udisks2.enable = true;

  # Unlock the keyring at login (the niri module enables gnome-keyring).
  security.pam.services.sddm.enableGnomeKeyring = true;
}
