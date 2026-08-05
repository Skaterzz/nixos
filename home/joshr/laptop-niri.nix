{ lib, niriScripts, ... }:

# joshr's home profile on the laptop, niri session.
#
# niri's per-monitor behaviour is driven by the outputs actually present
# rather than by hardcoded screen indices, so unlike the Plasma variant there
# is nothing single-display to switch off here.
#
# The display layout lives in ./displays/laptop.nix.
{
  imports = [
    ./home.nix
    ./niri
    ./niri/privacy.nix
    ./displays/laptop.nix
    ./desktop-apps.nix
    ./office.nix
    ./kitty.nix
    ./ranger.nix
    ./vscode.nix
    ./spicetify.nix
    ./firefox.nix
    ./browser.nix
    ./wallhaven.nix
  ];

  # No OpenRGB tray applet at login here, and nothing to switch off to get
  # that: `local.openrgb.autostart` defaults to whether the OpenRGB daemon is
  # enabled, and the daemon comes with modules/nixos/gaming.nix, which
  # hosts/laptop-niri doesn't import. The desk has RGB hardware worth driving;
  # here the applet would have nothing to talk to and would still cost a tray
  # icon, a Qt process and a failed profile load every session.
  #
  # Nothing OpenRGB-shaped is installed here at all, in fact: the package comes
  # from the daemon's own module (`services.hardware.openrgb` puts it in
  # environment.systemPackages), so no daemon means no `openrgb` on PATH
  # either. If a docked keyboard or mouse ever needs it, `nix run nixpkgs#openrgb`
  # is a one-off, and importing modules/nixos/gaming.nix on this host is the
  # permanent version.
  services.swayidle.events.lock = lib.mkForce (lib.getExe niriScripts.lockBlank);
}
