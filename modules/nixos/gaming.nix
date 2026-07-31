{ config, lib, pkgs, ... }:

{
  # MangoHud itself is configured per-user in home/joshr/home.nix
  # (home-manager's programs.mangohud, not a NixOS-level option).
  services.hardware.openrgb = {
	enable = true;
	package = pkgs.openrgb-with-all-plugins;
        motherboard = "amd";
};
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  environment.systemPackages = with pkgs; [
    prismlauncher
    protonup-qt
  ];

  programs.gamemode = {
    enable = true;

    settings = {
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };
}
