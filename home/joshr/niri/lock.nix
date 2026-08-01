{ config, lib, pkgs, niriScripts, ... }:

# Idle handling and the lock screen.
#
# The lock command itself is `lock-session` from scripts.nix — it reads its
# colours from the active theme, so the lock screen follows theme switches.
# This module is the idle timer and the sleep hook around it.
#
# `swaylock` needs a PAM entry to authenticate; that's set at system level in
# modules/nixos/niri.nix, since home-manager can't write /etc/pam.d.
let
  lock = lib.getExe niriScripts.lockSession;
in
{
  services.swayidle = {
    enable = true;

    # niri starts the session; tie the timer to the graphical session target.
    # (Singular `systemdTarget` is a renamed alias and warns.)
    systemdTargets = [ "graphical-session.target" ];

    events = [
      # Lock before the machine suspends, so it never resumes unlocked.
      {
        event = "before-sleep";
        command = lock;
      }
      # Handles `loginctl lock-session` from elsewhere.
      {
        event = "lock";
        command = lock;
      }
    ];

    timeouts = [
      # Dim first as a warning, restore on activity.
      {
        timeout = 240;
        command = "${pkgs.brightnessctl}/bin/brightnessctl -s set 20%";
        resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      }
      # Then lock.
      {
        timeout = 300;
        command = lock;
      }
      # Then blank the outputs. niri handles DPMS via its own IPC.
      {
        timeout = 360;
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
      }
    ];
  };

  home.packages = [ pkgs.swaylock-effects ];

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
