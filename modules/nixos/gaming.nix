{ config, lib, pkgs, ... }:

{
  # MangoHud itself is configured per-user in home/joshr/home.nix
  # (home-manager's programs.mangohud, not a NixOS-level option).
  services.hardware.openrgb.enable = true;
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };
}
