{ config, lib, pkgs, ... }:

{
  # Plasma's power-profile switcher (and the Meta+B shortcut carried over
  # from the dotfiles' powerdevil config) talks to power-profiles-daemon.
  # Note this conflicts with TLP — enable one or the other, not both.
  services.power-profiles-daemon.enable = true;

  powerManagement.enable = true;

  # Battery/AC state for the panel's battery widget.
  services.upower.enable = true;

  # Lets the kernel throttle before the laptop cooks itself under a long
  # compile. Intel-only; harmless to drop on an AMD machine.
  services.thermald.enable = lib.mkDefault true;

  # Trim for the SSD.
  services.fstrim.enable = true;
}
