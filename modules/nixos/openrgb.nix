{ config, lib, pkgs, ... }:

# RGB lighting: the OpenRGB daemon, and putting the profile back after a
# suspend.
#
# Imported by modules/nixos/gaming.nix, so it lands on whichever hosts import
# that — the two `gamestation` ones. It used to be four lines inside gaming.nix
# and moved out here when the resume half was added; RGB isn't gaming, it just
# arrived on the same machine.
#
# Why anything is needed on resume
# --------------------------------
# RGB controllers keep their colours because something wrote them, not because
# they remember anything. Suspend cuts power to most of them — the USB ones are
# re-enumerated on the way back up, and the SMBus ones on the board come back
# with whatever their firmware defaults to, which is usually the rainbow. The
# session applied `local.openrgb.profile` once, at login (the niri config
# spawns the tray applet with `--profile`, see home/joshr/niri/niri.nix), and
# nothing re-applies it afterwards. So the lighting is correct until the first
# suspend and wrong from then until the next login.
#
# This module re-runs that same apply after every resume.
#
# Why it runs as a user
# ---------------------
# Profiles are runtime state, not something this repo writes: they are made
# from OpenRGB's own UI ("Save Profile") and land in ~/.config/OpenRGB. So the
# command has to run as the account that owns them — `local.desktop.primaryUser`
# — and not as root, which would look in /root/.config/OpenRGB, find nothing,
# and print "Profile failed to load".
#
# That is also why this isn't `powerManagement.resumeCommands`, which is the
# NixOS-native version of the same hook: those commands all run as root inside
# one shared unit.
let
  cfg = config.local.openrgb;

  # The same build the daemon and the session use. `openrgb-with-all-plugins`
  # rather than plain `openrgb` because that is what was already configured
  # here, and the plugins are per-build rather than loadable from elsewhere.
  package = pkgs.openrgb-with-all-plugins;

  # Wait for the hardware, then apply the profile by name.
  #
  # The sleep is the part that isn't obvious. systemd considers the resume
  # finished as soon as the kernel comes back, which is well before USB has
  # re-enumerated — an OpenRGB run started at that instant simply doesn't see
  # a keyboard or an AIO pump yet, applies the profile to whatever did answer,
  # and exits. Five seconds is enough for a desktop's devices to reappear and
  # short enough not to be noticed.
  applyProfile = pkgs.writeShellApplication {
    name = "openrgb-apply-profile";
    runtimeInputs = [
      package
      pkgs.coreutils
    ];
    text = ''
      profile="''${1:-}"
      if [ -z "$profile" ]; then
        echo "usage: openrgb-apply-profile <profile-name>" >&2
        exit 2
      fi

      sleep 5

      # systemd sets HOME from the account database for a `User=` unit, so
      # this is the same path the session's own OpenRGB would look in.
      config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/OpenRGB"

      # A profile that doesn't exist is not an error worth failing a unit
      # over. Naming one before it has been saved is a normal state to be in
      # — OpenRGB itself just prints "Profile failed to load" and carries on
      # — and a red `systemctl status` after every resume would be noise.
      if [ ! -f "$config_dir/$profile.orp" ]; then
        echo "no profile at $config_dir/$profile.orp — leaving the lighting alone"
        exit 0
      fi

      # Given an option and no `--gui`/`--startminimized`, OpenRGB runs as a
      # CLI: it applies the profile and exits, which is exactly what's wanted
      # here. The login spawn passes `--startminimized` precisely to stop it
      # doing that and to leave a tray icon behind instead.
      openrgb --profile "$profile"
    '';
  };
in
{
  # local.* lives in its own module so this one can stay a config attrset.
  imports = [ ./options.nix ];

  services.hardware.openrgb = {
    enable = true;
    inherit package;

    # Loads i2c-piix4 alongside i2c-dev, which is the SMBus controller on an
    # AMD board — the bus the RAM and the motherboard headers sit on. The
    # other half of reaching them is `acpi_enforce_resources=lax`, in
    # hosts/gamestation/kernel-params.nix.
    motherboard = "amd";
  };

  # Re-apply the profile after every sleep.
  #
  # The shape of this unit is systemd's own recipe for "run something on
  # resume" (systemd.special(7), under sleep.target), and the one nixpkgs uses
  # for `powerManagement.resumeCommands`:
  #
  #   * `sleep.target` is common to suspend, hibernate, hybrid-sleep and
  #     suspend-then-hibernate, so one target covers all four rather than
  #     enumerating suspend.target, hibernate.target and friends.
  #
  #   * `Before=sleep.target` orders this unit ahead of the sleep on the way
  #     down, which — since systemd stops units in the reverse of the order it
  #     started them — is what puts its *stop* after the sleep, i.e. after the
  #     machine has woken up.
  #
  #   * So the work goes in `ExecStop`, and there is no ExecStart at all: a
  #     `Type=oneshot` service is allowed to carry one and not the other.
  #     `RemainAfterExit` is what keeps it "started" across the sleep so that
  #     there is something to stop, and `StopWhenUnneeded` is what makes that
  #     stop happen as soon as sleep.target is done with rather than at the
  #     next shutdown.
  #
  # The consequence to know about: `systemctl status openrgb-resume` reads
  # "active (exited)" whenever the machine is awake and has done nothing yet.
  # That is the unit armed, not the unit run. What it did last time is in the
  # journal:
  #
  #     journalctl -u openrgb-resume -b
  systemd.services.openrgb-resume = lib.mkIf cfg.applyOnResume {
    description = "Re-apply the OpenRGB profile after resume";

    wantedBy = [ "sleep.target" ];
    before = [ "sleep.target" ];
    unitConfig.StopWhenUnneeded = true;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      # Whoever owns ~/.config/OpenRGB. See the header.
      User = config.local.desktop.primaryUser;

      # OpenRGB is a Qt program even when it never draws anything, and this
      # runs outside any graphical session — no DISPLAY, no WAYLAND_DISPLAY.
      # Without a platform to fall back on, Qt aborts before OpenRGB's own
      # argument handling gets a look in.
      Environment = [ "QT_QPA_PLATFORM=offscreen" ];

      ExecStop = "${lib.getExe applyProfile} ${cfg.profile}";
    };
  };

  # If the lighting comes back on the board and the RAM but *not* on a USB
  # device (keyboard, mouse, an AIO pump), the profile is being applied through
  # the running daemon, whose handle on that device died when it was
  # re-enumerated. Re-detecting is what fixes that, and the blunt way to
  # re-detect is to restart the daemon before applying — add to the unit above:
  #
  #     serviceConfig.ExecStop = [
  #       "+${config.systemd.package}/bin/systemctl restart openrgb.service"
  #       "${lib.getExe applyProfile} ${cfg.profile}"
  #     ];
  #
  # (the `+` runs that one command as root, since restarting a system service
  # is not something the user this unit runs as can do). It is not the default
  # because it drops any SDK client connected to the daemon — the session's own
  # tray applet included — and that is a real cost to pay for a problem this
  # machine may not have.
}
