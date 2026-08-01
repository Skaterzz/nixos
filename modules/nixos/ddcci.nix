{ config, lib, pkgs, ... }:

# Brightness control for external monitors, over DDC/CI.
#
# The kernel's `backlight` class only ever contains *internal* panels — an
# eDP/LVDS display whose backlight PWM the GPU driver actually owns
# (intel_backlight, amdgpu_bl0, nv_backlight). A monitor on DisplayPort or
# HDMI never appears there, because its backlight is inside the monitor and
# the host has no register to write. So on a desktop `/sys/class/backlight` is
# empty, and every tool that drives brightness through it — brightnessctl,
# powerdevil, the swayidle dim in home/joshr/niri/lock.nix — silently does
# nothing. That is not a misconfiguration; there is no device to write to.
#
# The way to reach an external monitor is DDC/CI: a small command set the
# monitor answers on the I2C bus that runs alongside the video link, at
# address 0x37. `ddcutil` speaks it from userspace, but then every consumer
# needs teaching about a second, entirely different mechanism.
#
# This module takes the other route. ddcci-backlight is an out-of-tree driver
# that speaks DDC/CI in the kernel and registers each monitor it finds as an
# ordinary `/sys/class/backlight/ddcci*` device. Everything that already
# drives the laptop's panel then works on the desk unchanged — no per-host
# keybinds, no second code path in the idle timer.
#
# What it costs:
#
#   * An out-of-tree module, so it rebuilds whenever the kernel moves. If it
#     ever fails to build, the machine still boots — you just lose brightness
#     control again, so it fails in the direction it was already broken in.
#
#   * DDC/CI is slow (a write is a round trip on the order of 100ms) and not
#     every monitor implements it well. Some ignore it, some need it enabled
#     in their OSD under a name like "DDC/CI" or "MCCS".
#
# Deliberately not enabled on hosts/gamestation/configuration.nix (the Plasma
# variant of this machine). It would work there — powerdevil reads the same
# sysfs class — but it would also hand powerdevil's idle timer real dimming
# on displays it currently can't touch, which is a behaviour change nobody
# asked for. Enable it there on purpose if that's what you want.
#
# Check the result on the machine:
#
#     ls /sys/class/backlight/     # expect a ddcci* per monitor
#     brightnessctl --list
#     ddcutil detect               # what DDC/CI itself can see
let
  cfg = config.local.backlight.ddcci;

  # Bind the ddcci driver to one i2c bus, given its kernel name (`i2c-5`).
  #
  # The driver does implement i2c auto-detection, but that only fires on
  # adapters flagged I2C_CLASS_DDC, and the NVIDIA driver doesn't flag its
  # display adapters that way — so on this machine nothing would ever attach
  # by itself. Hence the explicit `new_device` write, driven from udev.
  #
  # Probing with ddcutil before binding is the point of the wrapper. Writing
  # to `new_device` unconditionally succeeds even when nothing answers, and
  # leaves a dead i2c client sitting on every bus that isn't a monitor.
  #
  # The retries are for the boot case: the buses appear as soon as the GPU
  # driver loads, which can easily be before a monitor has finished waking up
  # and is willing to answer DDC/CI.
  bindBus = pkgs.writeShellApplication {
    name = "ddcci-bind";
    runtimeInputs = with pkgs; [ ddcutil coreutils ];
    text = ''
      bus="''${1:-}"
      if [ -z "$bus" ]; then
        echo "usage: ddcci-bind <i2c-N>" >&2
        exit 2
      fi

      num="''${bus#i2c-}"

      # Already bound — a second write would create a duplicate client.
      if [ -e "/sys/bus/i2c/devices/$num-0037" ]; then
        exit 0
      fi

      for attempt in 1 2 3; do
        # VCP feature 0x10 is "luminance". Reading it is the cheapest
        # question that distinguishes a monitor from any other i2c device.
        if ddcutil --bus "$num" getvcp 0x10 >/dev/null 2>&1; then
          echo "ddcci 0x37" > "/sys/bus/i2c/devices/$bus/new_device"
          exit 0
        fi
        [ "$attempt" = 3 ] || sleep 2
      done

      # Not a monitor, or one that doesn't do DDC/CI. Nothing to attach, and
      # nothing wrong — most buses on a machine are not displays.
      exit 0
    '';
  };

  # One udev rule per adapter-name pattern. `$kernel` is the i2c-dev name
  # (`i2c-5`), which is what the template unit takes as its instance.
  udevRules = lib.concatMapStringsSep "\n" (
    pattern:
    ''SUBSYSTEM=="i2c-dev", ACTION=="add", ATTR{name}=="${pattern}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ddcci@$kernel.service"''
  ) cfg.busNameMatch;
in
{
  # local.* lives in its own module so this one can stay a config attrset.
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [ config.boot.kernelPackages.ddcci-driver ];

    # The package builds two modules, ddcci and ddcci-backlight. This is the
    # half that registers backlight devices; it pulls in the other by symbol
    # dependency. Loading it early is harmless — it only registers a driver,
    # and the devices arrive later from the `new_device` writes below.
    boot.kernelModules = [ "ddcci-backlight" ];

    # Loads i2c-dev, creates the `i2c` group, and sets group ownership and a
    # uaccess tag on /dev/i2c-*. The module load is the part ddcutil can't
    # work without; the uaccess tag is what lets `ddcutil detect` run as the
    # logged-in user rather than only as root.
    hardware.i2c.enable = true;

    services.udev.extraRules = udevRules;

    # brightnessctl's own udev rules, which chgrp the `brightness` attribute
    # of every backlight device to `video` and make it group-writable. joshr
    # is in `video` (modules/nixos/users.nix).
    #
    # These have never been installed in this repo — brightnessctl comes from
    # home.packages (home/joshr/niri/default.nix), which puts the binary on
    # PATH and nothing else. The laptop works anyway because brightnessctl
    # falls back to logind's SetBrightness for the active seat. That fallback
    # is worth not depending on here, since these devices are new and there
    # are several of them.
    services.udev.packages = [ pkgs.brightnessctl ];

    # Bound to each i2c bus by the udev rules above, so it runs once per
    # adapter as the adapter appears — which is also the correct ordering,
    # since the buses don't exist until the GPU driver has created them.
    systemd.services."ddcci@" = {
      description = "Attach the ddcci driver to i2c bus %i";
      after = [ "graphical.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe bindBus} %i";
      };
    };

    # For working out why a monitor isn't showing up. `ddcutil detect` is the
    # first thing to run when /sys/class/backlight stays empty.
    environment.systemPackages = [ pkgs.ddcutil ];
  };
}
