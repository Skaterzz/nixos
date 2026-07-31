{ config, lib, pkgs, ... }:

{
  # Force S3 ("deep") suspend instead of s2idle. Most current laptop firmware
  # defaults to s2idle, where the machine stays powered and merely idles —
  # which is why a "sleeping" laptop can lose most of its battery overnight
  # and run warm in a bag. S3 actually cuts power to the CPU and RAM stays in
  # self-refresh.
  #
  # This only works if the firmware offers S3 at all. Check on the machine:
  #
  #   cat /sys/power/mem_sleep
  #
  # The available modes are listed with the active one in brackets. If `deep`
  # isn't in that list, the firmware is s2idle-only and this parameter is
  # silently ignored — some vendors expose S3 behind a BIOS setting, often
  # called something like "Sleep State: Linux/S3" rather than "Modern
  # Standby".
  boot.kernelParams = [ "mem_sleep_default=deep" ];

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

  # Closing the lid suspends only on battery.
  #
  # HandleLidSwitchExternalPower defaults to whatever HandleLidSwitch is, so
  # it has to be set explicitly to get the "battery only" behaviour — setting
  # HandleLidSwitch alone would suspend on AC too.
  #
  # Docked is ignored separately: with the lid shut and external displays
  # attached, suspending is rarely what's wanted.
  #
  # (These live under services.logind.settings.Login now; the old
  # services.logind.lidSwitch* options are renamed aliases that warn.)
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
}
