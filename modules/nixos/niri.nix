{ config, lib, pkgs, ... }:

# System side of the niri desktop: the session itself, the display manager,
# and the bits home-manager can't write (PAM, polkit, system services).
#
# This replaces modules/nixos/desktop.nix on a host — importing both would
# enable two desktop sessions and two display-manager configs.
let
  # SDDM theme, recoloured green/black to match the desktop.
  #
  # sddm-astronaut takes a `themeConfig` attrset that is rendered into the
  # theme's .conf, so the palette is set declaratively rather than by patching
  # files in the store.
  sddmTheme = pkgs.sddm-astronaut.override {
    embeddedTheme = "black_hole";
    themeConfig = {
      # Background handled by the theme's own art; keep it dark.
      FullBlur = "false";
      PartialBlur = "true";
      BlurRadius = "60";
      DimBackground = "0.25";

      HeaderText = "Welcome";
      HourFormat = "HH:mm";
      DateFormat = "dddd, d MMMM";

      FormPosition = "center";
      BackgroundHorizontalAlignment = "center";
      BackgroundVerticalAlignment = "center";

      # Green on black.
      HeaderTextColor = "#39ff14";
      DateTextColor = "#c8f5c8";
      TimeTextColor = "#39ff14";
      FormBackgroundColor = "#0a0e0a";
      BackgroundColor = "#0a0e0a";
      DimBackgroundColor = "#000000";
      LoginFieldBackgroundColor = "#111811";
      PasswordFieldBackgroundColor = "#111811";
      LoginFieldTextColor = "#c8f5c8";
      PasswordFieldTextColor = "#c8f5c8";
      UserIconColor = "#39ff14";
      PasswordIconColor = "#39ff14";
      PlaceholderTextColor = "#5c7a5c";
      WarningColor = "#ff5555";
      LoginButtonTextColor = "#0a0e0a";
      LoginButtonBackgroundColor = "#39ff14";
      SystemButtonsIconsColor = "#39ff14";
      SessionButtonTextColor = "#c8f5c8";
      VirtualKeyboardButtonTextColor = "#c8f5c8";
      DropdownTextColor = "#c8f5c8";
      DropdownSelectedBackgroundColor = "#1f8b0d";
      DropdownBackgroundColor = "#111811";
      HighlightTextColor = "#0a0e0a";
      HighlightBackgroundColor = "#39ff14";
      HighlightBorderColor = "#39ff14";
      HoverUserIconColor = "#c8f5c8";
      HoverSystemButtonsIconsColor = "#c8f5c8";
      Font = "FiraCode Nerd Font";
      FontSize = "11";
    };
  };
in
{
  programs.niri.enable = true;

  # Display manager. SDDM's Wayland greeter is what niri wants; the X11
  # greeter would start an X server just to draw the login screen.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    theme = "sddm-astronaut-theme";
    extraPackages = [ sddmTheme ];
  };

  environment.systemPackages = [
    sddmTheme
    # qtsvg/qtmultimedia/qtvirtualkeyboard come through the theme's
    # propagatedBuildInputs.
  ];

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

  # Secrets for apps that expect a keyring (the niri module enables
  # gnome-keyring with mkDefault; this unlocks it at login).
  security.pam.services.sddm.enableGnomeKeyring = true;
}
