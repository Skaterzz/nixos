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
        timeout = 600;
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
      }
    ];
  };

  home.packages = [ pkgs.swaylock-effects ];
}
