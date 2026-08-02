{ config, lib, pkgs, ... }:

{
  # OpenRGB: the daemon, and re-applying the profile after a suspend.
  #
  # It lived here as four lines and moved out when the resume half was added.
  # Still imported from this file rather than per host, so the hosts that had
  # RGB before still have it and nothing had to be edited to keep it. Its
  # `local.openrgb.*` options are in modules/nixos/options.nix.
  imports = [ ./openrgb.nix ];

  # MangoHud isn't here at all: it's configured per-user in
  # home/joshr/home.nix, through home-manager's programs.mangohud rather than
  # a NixOS-level option.

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
  };

  programs.gamescope = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    prismlauncher
    protonup-qt
    lutris
  ];

  programs.gamemode = {
    enable = true;

    settings = {
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send -i input-gamepad 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send -i input-gamepad 'GameMode ended'";
      };
    };
  };
}
