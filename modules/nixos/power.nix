{ config, lib, pkgs, ... }:

# "Don't put the machine to sleep on its own unless it's running on battery."
#
# What actually decides that
# --------------------------
# Nothing in this config sets a single "auto-sleep" switch, because there
# isn't one. Automatic suspend can come from at least three places, and they
# don't know about each other:
#
#   logind    `IdleAction`, which NixOS leaves at "ignore" — but a future
#             edit, or a NixOS default change, would turn it on everywhere.
#   powerdevil  Plasma's own idle timer. Configured separately in
#             home/joshr/plasma.nix, which sets the AC profile's autosuspend
#             action to "nothing".
#   swayidle  the niri hosts' idle timer (home/joshr/niri/lock.nix). It dims,
#             locks and blanks but never suspends, so it isn't in scope here
#             — and deliberately so: "don't sleep" is not "don't lock".
#
# What this module adds is the general answer: while the machine is on mains
# power, hold a logind *idle* inhibitor. logind and anything that asks it —
# powerdevil included — then treat the session as busy and never fire an idle
# action, whatever their own timers say.
#
# `--what=idle`, not `idle:sleep`
# ------------------------------
# This is the one detail worth getting right. A `sleep` inhibitor blocks
# *every* suspend, including a deliberate one: `systemctl suspend` fails
# outright while it is held, so the session menu's "Suspend" entry and the
# lid switch would both stop working. An `idle` inhibitor blocks only the
# automatic, timer-driven path, which is exactly what "autosleep" means and
# exactly what was asked for.
#
# How it follows the plug
# -----------------------
# `ExecCondition` re-checks the power source every time the unit is started,
# and a udev rule restarts it on any power_supply event — so the condition is
# the single place the policy lives, and plugging or unplugging simply
# re-evaluates it. A machine with no battery at all — the desk, the server, a
# VM — counts as permanently on mains, so the inhibitor stays up there.
let
  cfg = config.local.power;

  # Exit 0 when the machine is running on mains, 1 when on battery.
  #
  # As an ExecCondition, exit 1 is not a failure — systemd skips the unit and
  # leaves it inactive, which is the state we want on battery. (Only an exit
  # of 255 or a signal makes the unit *fail*, hence the explicit exits rather
  # than falling off the end.)
  #
  # The rule is systemd's own, from `on_ac_power()`: a supply whose `type` is
  # anything but "Battery" and whose `online` is non-zero means mains. That
  # deliberately covers more than `type == "Mains"` — a USB-PD charger or a
  # Thunderbolt dock is a "USB" supply, and reports online=2 ("programmable")
  # rather than 1. Matching only Mains and only 1 would call a USB-C-charged
  # laptop "on battery" and let it sleep.
  onMainsPower = pkgs.writeShellApplication {
    name = "on-mains-power";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      have_battery=0

      for ps in /sys/class/power_supply/*; do
        # An empty class directory leaves the glob unexpanded.
        [ -e "$ps/type" ] || continue

        if [ "$(cat "$ps/type" 2>/dev/null || true)" = "Battery" ]; then
          have_battery=1
          continue
        fi

        # No `online` at all means the supply can't say, so it doesn't count.
        online="$(cat "$ps/online" 2>/dev/null || echo 0)"
        if [ "$online" != "0" ]; then
          exit 0
        fi
      done

      # Nothing is supplying power. On a machine that has a battery, that
      # means it is running on it; on one that has neither — a desktop whose
      # PSU the kernel doesn't model, a VM — there is nothing to run down, so
      # treat it as mains and keep the inhibitor.
      if [ "$have_battery" = "1" ]; then
        exit 1
      fi
      exit 0
    '';
  };

  unit = "no-auto-sleep-on-ac.service";
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.noAutoSleepOnAC {
    systemd.services.no-auto-sleep-on-ac = {
      description = "Hold off automatic sleep while on mains power";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";

        # Skips the unit cleanly (not "failed") when on battery, so the idle
        # timers there behave exactly as they did before this module.
        ExecCondition = lib.getExe onMainsPower;

        # systemd-inhibit holds the lock for as long as its child lives, so
        # the child is something that never exits and costs nothing.
        ExecStart = lib.concatStringsSep " " [
          "${config.systemd.package}/bin/systemd-inhibit"
          "--what=idle"
          "--who=nixos"
          "--why='On mains power'"
          "--mode=block"
          "${pkgs.coreutils}/bin/sleep infinity"
        ];

        Restart = "no";
      };
    };

    # Follow the plug. Without this the inhibitor would only ever be
    # evaluated at boot, so unplugging a laptop would leave it held and
    # plugging one in would never take it.
    #
    # `restart`, unconditionally, on any power_supply event — rather than a
    # pair of start/stop rules keyed on the attributes. That keeps the whole
    # policy in on-mains-power: a restart re-runs ExecCondition, which either
    # re-establishes the inhibitor or skips the unit and leaves it inactive.
    # The rules would otherwise have to duplicate that logic in udev's match
    # syntax, and get the USB-PD case (type "USB", online 2) wrong.
    #
    # `--no-block` because a udev rule must not wait on systemd: the worker
    # running it holds the device lock systemd itself wants, so a blocking
    # call there deadlocks until udev times the rule out.
    #
    # One rule per line, long as it is. udev does accept a trailing backslash
    # as a continuation, but a rule broken across lines is a classic way to
    # end up with a file that parses and quietly matches nothing.
    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", RUN+="${config.systemd.package}/bin/systemctl --no-block restart ${unit}"
    '';
  };
}
