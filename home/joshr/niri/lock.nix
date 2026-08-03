{ config, lib, pkgs, niriScripts, ... }:

# Idle handling and the lock screen.
#
# The lock screen itself is `lock-session` from scripts.nix — it reads its
# colours from the active theme, so it follows theme switches. This module is
# the idle timer and the sleep hook around it.
#
# `swaylock` needs a PAM entry to authenticate; that's set at system level in
# modules/nixos/niri.nix, since home-manager can't write /etc/pam.d.
let
  # `lock-now`, never `lock-session`, and that is the difference between this
  # timer working and stopping dead the moment it locks.
  #
  # home-manager runs swayidle with `-w` (services.swayidle.extraArgs), and
  # with `-w` swayidle forks the command once and then waits on it from inside
  # its own Wayland event loop rather than double-forking and carrying on
  # (cmd_exec, main.c). `lock-session` blocks until you type your password, so
  # a timeout pointed at it froze every later timer at the instant of the
  # lock: the 600s blank below never fired, and the screen stayed lit behind
  # the lock screen until it was unlocked. `lock` and `before-sleep` wedged
  # the same way.
  #
  # `lock-now` starts the locker, waits only until it is up, and returns in a
  # few hundred milliseconds — which keeps what `-w` is actually for (swayidle
  # holds logind's sleep delay lock until before-sleep returns, so the machine
  # can't suspend ahead of the locker) without keeping what it cost. See the
  # comment on lockNow in scripts.nix.
  lock = lib.getExe niriScripts.lockNow;

  # The idle lock, and the only lock on the machine with a grace period.
  #
  # `lock-session` defaults to `--grace 0`: every other route to the lock is
  # something you asked for — a keybind, the bar, the session menu, a suspend,
  # `loginctl lock-session` — and on those a window in which any keypress
  # dismisses the lock without a password is a hole, not a convenience, since
  # waking the screen to confirm it locked would walk straight through it.
  #
  # This one is different because nobody asked for it. The timer fires on its
  # own after five minutes away, and the case it has to handle is the timer
  # firing as you sit back down. Two seconds covers that and nothing longer.
  idleLock = "${lock} --grace 2";
in
{
  services.swayidle = {
    enable = true;

    # niri starts the session; tie the timer to the graphical session target.
    # (Singular `systemdTarget` is a renamed alias and warns.)
    systemdTargets = [ "graphical-session.target" ];

    # An attrset keyed by event name. The old list of `{ event; command; }`
    # pairs still works — home-manager coerces it — but warns, and the set is
    # the honest shape anyway: swayidle takes one command per event, so two
    # entries for the same event were never meaningful.
    events = {
      # Lock before the machine suspends, so it never resumes unlocked. No
      # grace: resuming from suspend is exactly the moment a free keypress
      # would be spent, and the lid may well have been closed deliberately.
      before-sleep = lock;

      # Handles `loginctl lock-session` from elsewhere. Someone asked for the
      # lock, so no grace either.
      lock = lock;
    };

    timeouts = [
      # Dim first as a warning, restore on activity.
      #
      # Through `brightness` (scripts.nix) so this covers every display, not
      # just whichever backlight device brightnessctl happened to enumerate
      # first. On the desk that's one device per monitor — before ddcci
      # existed there were none at all, so this dim was silently a no-op
      # there and the screen went straight from full brightness to locked.
      {
        timeout = 240;
        command = "${lib.getExe niriScripts.brightness} dim 20";
        resumeCommand = "${lib.getExe niriScripts.brightness} restore";
      }
      # Then lock. The one lock that keeps a grace period — see idleLock.
      {
        timeout = 300;
        command = idleLock;
      }
      # Then blank the outputs. niri handles DPMS via its own IPC, and
      # `power-off-monitors` is on its whitelist of actions that still run
      # while the session is locked, so this fires through the lock above.
      {
        timeout = 600;
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
      }
    ];
  };

  # The patched swaylock build from scripts.nix keeps the date within its
  # ring. Hyprlock no longer needs a custom source patch.
  home.packages = [
    niriScripts.swaylock
    pkgs.hyprlock
  ];

  # The sleep inhibitor: "keep this machine awake until I say otherwise".
  #
  # Started and stopped by `idle-inhibit` (scripts.nix), which is bound to
  # Mod+Shift+I and to the waybar module. Deliberately has no wantedBy, so it
  # only ever runs on demand and every session starts with idling normal.
  #
  # Two separate things have to be held off, because they're unrelated
  # mechanisms:
  #
  #   swayidle  dims, locks and blanks. It takes its cue from the
  #             compositor's idle-notify protocol, *not* from logind, so a
  #             logind inhibitor has no effect on it whatsoever — the timer
  #             has to be stopped outright or the screen still goes dark.
  #
  #   logind    suspends: the idle action, the sleep transition, and the lid
  #             switch. systemd-inhibit holds a block lock on all three for
  #             as long as its child process lives, which is what the
  #             `sleep infinity` is for.
  #
  # The systemctl calls are prefixed `-` so a failure to stop or restart
  # swayidle can't leave the unit in a failed state — worst case the idle
  # timer is where it was, which is recoverable by toggling again.
  systemd.user.services.idle-inhibit = {
    Unit.Description = "Inhibit idle actions and system sleep";
    Service = {
      Type = "simple";
      ExecStartPre = "-${pkgs.systemd}/bin/systemctl --user stop swayidle.service";
      # One line on purpose: this is rendered into an INI value, and a
      # multi-line string would need systemd's backslash continuations to
      # survive the generator intact.
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.systemd}/bin/systemd-inhibit"
        "--what=idle:sleep:handle-lid-switch"
        "--who=niri"
        "--why='Manually inhibited'"
        "--mode=block"
        "${pkgs.coreutils}/bin/sleep infinity"
      ];
      ExecStopPost = "-${pkgs.systemd}/bin/systemctl --user start swayidle.service";
    };
  };
}
