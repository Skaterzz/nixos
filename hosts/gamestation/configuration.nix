{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/virtualisation.nix
    ../../modules/nixos/users.nix
  ];

  networking.hostName = "gamestation";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "24.11";
}
