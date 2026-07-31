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

  # --- the greeter's display layout ---------------------------------------
  #
  # SDDM's Wayland greeter runs its own kwin_wayland, which knows nothing
  # about niri and takes its layout from kwinoutputconfig.json in the sddm
  # user's home. This generates that file from the very same
  # local.niri.outputs the session uses, so home/joshr/displays/<host>.nix
  # stays the one place a monitor change is described.
  #
  # Why generate rather than copy
  # -----------------------------
  # The previous attempt copied the file KWin had written for joshr, on the
  # theory that a from-scratch file would be ignored for lacking the EDID
  # fields KWin matches monitors by. That was the wrong read of
  # OutputConfigurationStore::findOutputIndex: the EDID comparison is only
  # reached when the *saved entry* carries an EDID identifier. An entry
  # without one falls through to matching on connector name, which is
  # exactly what this writes. Copying a whole Plasma arrangement also
  # dragged along its enabled/disabled state, which is the likeliest reason
  # the greeter came up on one display.
  #
  # Failure modes, deliberately
  # ---------------------------
  # Nothing here ever writes "enabled": false. If a connector name doesn't
  # match what the greeter sees, KWin finds no saved entry and auto-detects
  # that output — it lights up rather than staying dark. Same if the JSON is
  # malformed or the setup doesn't match: KWin falls back to detection. The
  # one genuinely bad case is a mode the display can't take, and these modes
  # come from the file niri already drives the same monitors with.
  #
  # If it still comes out wrong, the recovery is a TTY (Ctrl+Alt+F2):
  #
  #     sudo rm /var/lib/sddm/.config/kwinoutputconfig.json
  #
  # which restores auto-detection until the next rebuild, or set
  # local.sddm.syncGreeterDisplays = false to stop generating it. Booting
  # the previous generation works too.
  kwinOutputSddm = "/var/lib/sddm/.config/kwinoutputconfig.json";

  # The session's own display config, read straight out of home-manager.
  greeterOutputs = lib.filter (o: !o.off) config.home-manager.users.joshr.local.niri.outputs;

  # niri writes rotation as "90"/"flipped-90"; KWin spells them differently.
  kwinTransform =
    t:
    if t == null then
      "normal"
    else
      {
        "normal" = "normal";
        "90" = "rotate-90";
        "180" = "rotate-180";
        "270" = "rotate-270";
        "flipped" = "flipped";
        "flipped-90" = "flipped-90";
        "flipped-180" = "flipped-180";
        "flipped-270" = "flipped-270";
      }
      .${t} or "normal";

  # "2560x1440@180.000" -> { width, height, refreshRate } with the rate in
  # millihertz, which is what KWin stores. Via fromJSON rather than string
  # arithmetic so a fractional rate like 59.951 survives, and because
  # lib.toInt would choke on the leading zeros in "000".
  parseMode =
    m:
    let
      parts = if m == null then null else builtins.match "([0-9]+)x([0-9]+)@([0-9.]+)" m;
    in
    if parts == null then
      null
    else
      {
        width = lib.toInt (builtins.elemAt parts 0);
        height = lib.toInt (builtins.elemAt parts 1);
        refreshRate = builtins.floor (builtins.fromJSON (builtins.elemAt parts 2) * 1000.0 + 0.5);
      };

  # Per-monitor settings. No edidIdentifier or edidHash on purpose — that's
  # what selects connector-name matching, and the connector names here are
  # the ones `niri msg outputs` reports.
  outputEntry =
    o:
    let
      mode = parseMode o.mode;
    in
    {
      connectorName = o.name;
      scale = if o.scale == null then 1 else o.scale;
      transform = kwinTransform o.transform;
      vrrPolicy = if o.variableRefreshRate then "automatic" else "never";
    }
    // lib.optionalAttrs (mode != null) {
      mode = {
        basic = mode;
        flags = 0;
      };
    };

  # Arrangement. Positions live here rather than on the output entries.
  #
  # KWin treats priority 0 as the primary display. niri has no such concept,
  # so focusAtStartup — the nearest equivalent, and what the session already
  # uses — is ordered first.
  orderedOutputs =
    lib.filter (o: o.focusAtStartup) greeterOutputs ++ lib.filter (o: !o.focusAtStartup) greeterOutputs;

  priorityOf =
    o:
    let
      go = i: l: if l == [ ] then 0 else if (builtins.head l).name == o.name then i else go (i + 1) (builtins.tail l);
    in
    go 0 orderedOutputs;

  setupEntry = i: o: {
    outputIndex = i;
    enabled = true;
    priority = priorityOf o;
    position =
      if o.position == null then
        {
          x = 0;
          y = 0;
        }
      else
        {
          inherit (o.position) x y;
        };
  };

  kwinOutputFile = pkgs.writeText "kwinoutputconfig.json" (
    builtins.toJSON [
      {
        name = "outputs";
        data = map outputEntry greeterOutputs;
      }
      {
        name = "setups";
        data = [ { outputs = lib.imap0 setupEntry greeterOutputs; } ];
      }
    ]
  );

  # Only write one if there's something to say. The laptop leaves outputs
  # empty on purpose, and there auto-detection is the right answer.
  writeGreeterOutputs = config.local.sddm.syncGreeterDisplays && greeterOutputs != [ ];

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

    # --- greeter display layout ---------------------------------------
    # See the kwinOutputSddm note above. Written fresh every run rather than
    # only when absent, so editing displays/<host>.nix and rebuilding is
    # enough — otherwise a stale file from an earlier build would win
    # forever, which is state under /var/lib that NixOS won't clean up.
    ${
      if writeGreeterOutputs then
        ''
          # The parent is the sddm user's home. Created explicitly with the
          # right owner because this service can run before sddm ever has,
          # and `install -d` would otherwise leave a root-owned home that
          # the greeter can't write to.
          install -d -m 0750 -o sddm -g sddm /var/lib/sddm
          install -d -m 0700 -o sddm -g sddm /var/lib/sddm/.config
          install -m 0600 -o sddm -g sddm \
            ${kwinOutputFile} "${kwinOutputSddm}"
        ''
      else
        ''
          # No outputs configured for this host: let kwin auto-detect, and
          # clear anything an earlier build left behind.
          rm -f "${kwinOutputSddm}"
        ''
    }
  '';
in
{
  # local.sddm.* lives in its own module so this one can stay a plain config
  # attrset — declaring an option here would mean wrapping everything below
  # in `config = { … }`.
  imports = [ ./options.nix ];

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
