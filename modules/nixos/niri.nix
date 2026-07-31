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

      # Qt date/time format strings, not strftime: `h` is the hour without a
      # leading zero and drops to 1–12 as soon as an AM/PM field is present,
      # and `AP` is that field. Month before day, same as the session.
      HourFormat = "h:mm AP";
      DateFormat = "dddd, MMMM d";

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

          # NOTE: no primaryScreen patch here, on purpose.
          #
          # SDDM does set a `primaryScreen` bool per view (GreeterApp.cpp),
          # and binding the form's visibility to it looked like the clean way
          # to get "form on one display, wallpaper on the other". In practice
          # it hid the form on *both* — under the greeter's kwin_wayland,
          # QGuiApplication::primaryScreen() evidently matches neither view's
          # screen, so the property is false everywhere rather than undefined,
          # and the typeof guard never fires.
          #
          # The form and wallpaper therefore render on every display, which is
          # sddm-astronaut's stock behaviour.

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

  # Leftover state from an abandoned experiment.
  #
  # Earlier versions wrote a kwinoutputconfig.json here so the greeter's
  # kwin_wayland would reproduce the session's display layout. It never
  # worked, and the whole idea is gone — but the file is state under
  # /var/lib, which NixOS does not clean up for code it no longer builds.
  # Left behind it would keep being applied by any kwin-based greeter, so
  # the sync service deletes it unconditionally.
  kwinOutputSddm = "/var/lib/sddm/.config/kwinoutputconfig.json";

  themeDropIn = "/etc/sddm.conf.d/99-niri-active-theme.conf";

  # A solid image in each palette's background colour, so sddmWallpaper always
  # exists.
  #
  # This is the leading suspect for the black greeter. The theme config points
  # Background at a fixed runtime path, and that file only appears once the
  # wallpaper switcher has run — on a fresh boot, or before ever picking a
  # wallpaper, it isn't there. sddm-astronaut then feeds a missing image into
  # a blur shader (PartialBlur is on), and a QML scene graph that fails while
  # building an effect chain renders nothing at all rather than falling back
  # to BackgroundColor. That would look exactly like what happened: no error
  # from SDDM, which had already reported the greeter started and connected,
  # and identical behaviour on every display server, because none of them are
  # involved.
  #
  # Unproven — the greeter's own QML warnings were never captured — but it is
  # the only path here that referenced a file that might not exist, it costs
  # a few KB per palette, and it makes the themed greeter safe to retry.
  fallbackWallpapers = lib.mapAttrs (
    name: t:
    pkgs.runCommand "sddm-fallback-${name}.png" { } ''
      ${pkgs.imagemagick}/bin/magick -size 1920x1080 "xc:${t.bg}" "png:$out"
    ''
  ) themes;

  # `name) fallback="/nix/store/..." ;;` arms for the script's case.
  wallpaperCaseArms = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (n: p: ''            ${n}) fallback="${p}" ;;'') fallbackWallpapers
  );

  syncSddmTheme = pkgs.writeShellScript "sddm-theme-sync" ''
    set -eu

    # --- palette ------------------------------------------------------
    ${
      if useAstronaut then
        ''
          name="$(cat ${themeStateFile} 2>/dev/null || true)"
          case "$name" in
${wallpaperCaseArms}
            *)
              name="${themeSet.default}"
              fallback="${fallbackWallpapers.${themeSet.default}}"
              ;;
          esac

          mkdir -p /etc/sddm.conf.d
          printf '[Theme]\nCurrent=niri-%s\n' "$name" > "${themeDropIn}"
        ''
      else
        ''
          # Stock greeter: drop the override naming a niri-<theme> package.
          #
          # This is not tidying, it is the difference between a login screen
          # and a black one. The drop-in lives in /etc and NixOS only removes
          # files it declares, so without this it would outlive the packages
          # it names and point SDDM at a theme directory that is no longer in
          # the store.
          rm -f "${themeDropIn}"
        ''
    }

    # --- wallpaper ----------------------------------------------------
    # The greeter runs as the sddm user and can't read joshr's home, so the
    # image is copied somewhere world-readable. The theme config names a
    # fixed path (see sddmWallpaper), and only the file behind it changes.
    #
    # Converted to PNG rather than copied: the state file may point at a
    # .jpg, and naming a JPEG "wallpaper.png" leaves the format to QML's
    # content sniffing. Converting removes the guess.
    ${lib.optionalString useAstronaut ''
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

      # Guarantee the file the theme names actually exists. See the
      # fallbackWallpapers note: a missing background is not a cosmetic
      # problem here, it feeds a blur shader and can take the whole greeter
      # down with it. Only used when nothing above produced an image — a
      # first boot, or before a wallpaper has ever been chosen.
      if [ ! -f "${sddmWallpaper}" ]; then
        install -m 0644 "$fallback" "${sddmWallpaper}"
      fi
    ''}

    # --- clean up the abandoned display sync --------------------------
    # See the kwinOutputSddm note above: /var/lib state that NixOS won't
    # remove on its own, and that a kwin greeter would still obey.
    rm -f "${kwinOutputSddm}"
  '';

  useAstronaut = config.local.sddm.theme == "astronaut";
in
{
  # local.sddm.* lives in its own module so this one can stay a plain config
  # attrset — declaring an option here would mean wrapping everything below
  # in `config = { … }`.
  imports = [ ./options.nix ];

  programs.niri.enable = true;

  # Display manager.
  #
  # `theme` is left unset under local.sddm.theme = "stock", which gives
  # SDDM's own built-in greeter: no external theme package, no QML of ours,
  # no runtime state. That is the configuration to fall back to whenever the
  # login screen misbehaves, because almost nothing in it is our code.
  services.displayManager.sddm = {
    enable = true;
    # Both of these are options rather than edits, because they're the two
    # things worth varying when the greeter misbehaves. See local.sddm.*.
    wayland.enable = config.local.sddm.wayland;
    wayland.compositor = config.local.sddm.compositor;
    package = pkgs.kdePackages.sddm;

    # Cursor for the greeter.
    #
    # SDDM ships no cursor of its own — it reads these and exports
    # XCURSOR_THEME/XCURSOR_SIZE into the greeter, which then looks the name
    # up in the *system* icon path. Without them the greeter inherits
    # whatever the compositor defaults to, which on a bare login screen is
    # frequently nothing at all, and you get an invisible pointer.
    #
    # The session's cursor is set by home.pointerCursor in home/joshr/home.nix
    # and the greeter cannot see it: it runs as the `sddm` user before anyone
    # has logged in. Same names on both sides so the pointer doesn't change
    # shape at login; bibata-cursors is already in environment.systemPackages
    # (modules/nixos/base.nix), which is what puts it on the system icon path.
    settings.Theme = {
      CursorTheme = "Bibata-Modern-Ice";
      CursorSize = 24;
    };
  }
  // lib.optionalAttrs useAstronaut {
    theme = defaultSddmTheme;
    extraPackages = lib.attrValues sddmThemes;
  };

  # Every themed variant must be on the system so the greeter can switch
  # between them without a rebuild.
  environment.systemPackages = lib.optionals useAstronaut (lib.attrValues sddmThemes);

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
  #
  # It runs under "stock" too, and has to: it removes the /etc drop-in naming
  # a theme package that no longer exists, and the abandoned display-sync
  # file. Both are unmanaged state that would otherwise outlive the code that
  # made them and keep pointing the greeter at things that aren't there.
  systemd.services.sddm-theme-sync = {
    description = "Mirror the desktop theme and wallpaper to the SDDM greeter";
    wantedBy = [ "multi-user.target" ];

    # Must land before the greeter reads its config, or the first boot after
    # a switch still uses the state this is about to fix — which would look
    # exactly like the change not working. Ordering only: if this fails,
    # SDDM still starts.
    before = [ "display-manager.service" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = syncSddmTheme;
    };
  };

  systemd.paths.sddm-theme-sync = lib.mkIf useAstronaut {
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

  services.logind.settings.Login = {
    # On battery, preserve the current suspend behaviour.
    HandleLidSwitch = "suspend";

    # While plugged in, lock without suspending.
    HandleLidSwitchExternalPower = "lock";

    # A system with multiple displays may count as docked.
    HandleLidSwitchDocked = "lock";
  };
}
