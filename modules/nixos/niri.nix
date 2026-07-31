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
  sddmThemeConfig =
    t:
    {
      FullBlur = "false";
      PartialBlur = "true";
      BlurRadius = "60";
      DimBackground = "0.25";
      CropBackground = "true";

      HeaderText = "Welcome";
      HourFormat = "HH:mm";
      DateFormat = "dddd, d MMMM";
      FormPosition = "center";

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

      Font = "FiraCode Nerd Font";
      FontSize = "11";
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
          mv "$out/share/sddm/themes/sddm-astronaut-theme" \
             "$out/share/sddm/themes/niri-${name}"
        '';
      });

  sddmThemes = lib.mapAttrs mkSddmTheme themes;

  defaultSddmTheme = "niri-${themeSet.default}";

  # Watches the user's theme selection and rewrites an SDDM drop-in so the
  # login screen matches. SDDM only reads its config when the greeter starts,
  # so this takes effect at the next logout/reboot rather than immediately.
  themeStateFile = "/home/joshr/.local/state/niri-theme/current";

  syncSddmTheme = pkgs.writeShellScript "sddm-theme-sync" ''
    set -eu
    name="$(cat ${themeStateFile} 2>/dev/null || true)"
    [ -n "$name" ] || exit 0

    # Only accept names we actually built a theme for.
    case "$name" in
    ${lib.concatStringsSep "\n" (map (n: "      ${n}) ;;") (lib.attrNames themes))}
      *) exit 0 ;;
    esac

    mkdir -p /etc/sddm.conf.d
    printf '[Theme]\nCurrent=niri-%s\n' "$name" \
      > /etc/sddm.conf.d/99-niri-active-theme.conf
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

  # --- keep the login screen in step with the desktop theme --------------
  #
  # The greeter runs as the sddm user before anyone logs in, so it can't read
  # joshr's state directly, and /etc is store-managed. This writes one
  # unmanaged drop-in under /etc/sddm.conf.d/ (NixOS only removes files it
  # declares, so it survives) naming the matching theme.
  systemd.services.sddm-theme-sync = {
    description = "Match the SDDM theme to the selected desktop theme";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = syncSddmTheme;
    };
  };

  systemd.paths.sddm-theme-sync = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = [ themeStateFile ];
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
