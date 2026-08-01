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

  # What closing the lid does. Three cases:
  #
  #   on battery              suspend
  #   on mains, not docked    lock the session
  #   docked                  nothing
  #
  # "Docked" is logind's own definition and it is broader than a dock: an
  # ACPI dock station reporting docked, *or* at least one external display
  # connected (`manager_is_docked_or_external_displays`). Shutting a laptop
  # that is driving a monitor is the case that wants nothing to happen — the
  # session stays up on the external screen rather than locking behind a lid
  # nobody was looking at.
  #
  # The order those three are tested in is what makes that work, and it's
  # logind's, not ours: docked is checked first, then external power, then
  # the plain case. A dock supplies power, so the other order would never
  # reach the docked rule and a docked laptop would lock.
  #
  # HandleLidSwitchExternalPower is ignored entirely unless it is set, for
  # backwards compatibility — leave it out and mains falls through to
  # HandleLidSwitch, which is to say it suspends.
  #
  # `lock` doesn't suspend. It asks every session to lock, which under niri
  # is swayidle's `lock` event running lock-session (home/joshr/niri/lock.nix)
  # — the same path `loginctl lock-session` takes. On battery the lock still
  # happens, one step later: swayidle's `before-sleep` fires on the way down,
  # so the machine never resumes unlocked either way.
  #
  # `lock` and `suspend` differ in one place, and it is logind's doing rather
  # than a setting: while the lid stays shut logind keeps re-evaluating which
  # of the three cases applies, but the lock is only ever sent on the closing
  # edge — it is deliberately a no-op on those rechecks, or it would re-lock
  # on every wakeup. So pulling the monitor out of an already-closed laptop
  # suspends it if that leaves it on battery, and leaves the session as it was
  # if it is still plugged in. Opening and shutting the lid locks it.
  #
  # modules/nixos/power.nix doesn't get in the way of this, even though "on
  # mains" is exactly when it holds its idle inhibitor:
  # LidSwitchIgnoreInhibited defaults to yes, so lid handling ignores the
  # high-level idle and sleep locks. The low-level handle-lid-switch lock is
  # always honoured, which is how Mod+Shift+I (idle-inhibit, also in lock.nix)
  # still stops the lid doing anything at all.
  #
  # Under Plasma none of this fires: powerdevil takes a block inhibitor on
  # handle-lid-switch at session start and implements the lid itself, so the
  # same three cases are restated for it in home/joshr/laptop.nix. What's
  # here still covers the greeter and a bare TTY on that host.
  #
  # This module is the single owner of the logind half. modules/nixos/niri.nix
  # used to set the same three keys as well, and disagreed with this file.
  # laptop-niri imports both, and two modules setting one option to different
  # values is a conflict NixOS refuses to merge, so that host could not build
  # at all.
  #
  # (These live under services.logind.settings.Login now; the old
  # services.logind.lidSwitch* options are renamed aliases that warn.)
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "ignore";
  };
}
