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

  # Prefix for the timers that touch the screen rather than the session — see
  # the comment on whenActive in scripts.nix. Short version: several people can
  # be logged in at once, each session runs its own swayidle, and niri keeps
  # the idle clock running in a session that has been switched away from. The
  # brightness and DPMS commands below reach hardware the whole seat shares, so
  # a background session running them dims and blanks the screen of whoever is
  # actually at the machine.
  whenActive = lib.getExe niriScripts.whenActive;
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
      # Lock before the machine suspends, so it never resumes unlocked.
      #
      # `--grace 0` explicitly, rather than leaning on the `lock-session`
      # default, because this is the route where a grace window would be
      # worst: it is spent at resume, when the keypress or lid-open that wakes
      # the machine is itself the input that would dismiss the lock. A suspend
      # can be idle-triggered, but the lock it leaves behind is not an idle
      # lock — nobody is sitting in front of it, and the lid was usually
      # closed deliberately. Pinning it here keeps that true if the default
      # ever moves.
      before-sleep = "${lock} --grace 0";

      # Restart Dunst shortly after resume so any stale layer-shell
      # notification surface left over from before suspend is discarded, and
      # put the monitors' brightness back in agreement with what the machine
      # thinks it is.
      #
      # The second half is the same repair as the blank's resumeCommand below
      # and for the same reason — a suspend is a longer, harder version of the
      # screen going dark, and the displays lost power rather than just their
      # signal. Detached for the same reason too: swayidle's `-w` waits, and
      # this one already spends a second not doing anything.
      after-resume = lib.concatStringsSep " " [
        "${pkgs.coreutils}/bin/sleep 1;"
        "${pkgs.systemd}/bin/systemctl --user restart dunst.service;"
        "${pkgs.systemd}/bin/systemd-run --user --quiet --collect --"
        "${whenActive} ${lib.getExe niriScripts.brightness} sync"
      ];

      # Handles `loginctl lock-session` from elsewhere. Someone asked for the
      # lock, so no grace either.
      lock = lock;

      # And the other half of that pair: logind's Unlock signal takes the lock
      # screen away again.
      #
      # This is what stops switch-user asking for the password twice. SDDM
      # reuses a session rather than starting a second one for a user who is
      # already logged in (Users.ReuseSession, modules/nixos/niri.nix), and the
      # way it does that is UnlockSession followed by ActivateSession — so
      # authenticating at the greeter already *is* the authentication for the
      # session it drops you back into, and without something listening for
      # the unlock you would arrive at your own lock screen and type the same
      # password again.
      #
      # Only the session's own user and root can send it (see unlock-session),
      # and the sender here is SDDM having just been through PAM.
      #
      # Listening for it here does mean the listener goes away while the idle
      # inhibitor is on, since that stops swayidle outright — switch away and
      # back with `Mod+Shift+I` held on and the lock screen asks for the
      # password, exactly as it did before any of this. That is the old
      # behaviour rather than a new failure, and it is not worth a second
      # long-running D-Bus listener of our own to close.
      unlock = lib.getExe niriScripts.unlockSession;
    };

    timeouts = [
      # Dim first as a warning, restore on activity.
      #
      # Through `brightness` (scripts.nix) so this covers every display rather
      # than whichever backlight device happens to come first. On the desk
      # that's one device per monitor — before ddcci existed there were none
      # at all, so this dim was silently a no-op there and the screen went
      # straight from full brightness to locked.
      #
      # The pre-dim levels are recorded by the helper rather than by
      # brightnessctl's --save, which had no idea whether it had already
      # saved: a second dim with no restore between overwrote the saved level
      # with the dimmed one, and every restore after that returned the screen
      # to 20%. See `dim` in scripts.nix.
      #
      # Through `when-active` because a monitor's brightness belongs to the
      # seat, not to the session that set it: on the desk this is a DDC/CI
      # write to the panel itself, and it would land on the screen of whoever
      # is using the machine, from the session of somebody who isn't.
      {
        timeout = 240;
        command = "${whenActive} ${lib.getExe niriScripts.brightness} dim 20";
        resumeCommand = "${whenActive} ${lib.getExe niriScripts.brightness} restore";
      }
      # Then lock. The one lock that keeps a grace period — see idleLock.
      #
      # Not gated on the session being active, unlike its neighbours here. A
      # session that has been switched away from is one nobody is sitting in
      # front of, which is the case the idle lock exists for; it draws its lock
      # screen on its own session and nothing about that reaches the display
      # someone else is using.
      {
        timeout = 300;
        command = idleLock;
      }
      # Then blank the outputs. niri handles DPMS via its own IPC, and
      # `power-off-monitors` is on its whitelist of actions that still run
      # while the session is locked, so this fires through the lock above.
      #
      # Gated for the same reason as the dim, with one addition: a paused niri
      # has handed its DRM devices back, so this can't blank anything while the
      # session is in the background anyway — it would only queue the outputs
      # up to come back dark on the way in.
      #
      # **Undo the dim first, while the monitors can still hear it.** This is
      # the fix for the desk coming back out of blank at the wrong brightness.
      # The dim is a warning that the screen is about to go; once it has gone
      # there is nothing left for it to warn about, so putting the level back
      # before the outputs go dark costs nothing you can see. What it buys is
      # that no DDC/CI write is left owed across a DPMS off. Left to the
      # dim's own resumeCommand, that write goes out at the moment input
      # returns — racing niri turning the outputs back on, and landing on a
      # monitor that is still re-establishing its link and in no state to
      # answer. The driver doesn't notice it was ignored (see `brightness` in
      # scripts.nix), so sysfs said 100%, the panel sat at 20%, and the keys
      # then stepped from 100 and appeared dead until they had come back down
      # past 20. Restoring here, five minutes earlier, means the monitor takes
      # the write while it is awake and there is nothing pending when it
      # sleeps.
      #
      # `restore` is a no-op if the dim never ran, and the resumeCommand above
      # is then a no-op in turn — whichever of the two gets there first clears
      # the state and the other has nothing to do.
      {
        timeout = 600;
        command = lib.concatStringsSep " " [
          "${whenActive} ${lib.getExe niriScripts.brightness} restore;"
          "${whenActive} ${pkgs.niri}/bin/niri msg action power-off-monitors"
        ];

        # And on the way back, check rather than assume. A monitor that came
        # back on its own stored level instead of the one it was sent, or that
        # was polled while asleep and answered nonsense, is put right here; if
        # everything already agrees this reads each display once and stops.
        #
        # Detached through systemd-run because swayidle runs with `-w` and
        # waits for each command — see the comment on `lock` at the top of
        # this file. `brightness sync` deliberately keeps trying for a few
        # seconds while a monitor wakes up, and blocking swayidle's event loop
        # for that long is the exact mistake `lock-now` exists to avoid.
        resumeCommand = lib.concatStringsSep " " [
          "${pkgs.systemd}/bin/systemd-run --user --quiet --collect --"
          "${whenActive} ${lib.getExe niriScripts.brightness} sync"
        ];
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
