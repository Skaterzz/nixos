{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop.nix
    # Workaround for nixpkgs#126590 (huge XDG_DATA_DIRS makes every app slow
    # to start). Rebuilds plasma-workspace from source — remove this import
    # if the build cost outweighs the win.
    ../../modules/nixos/plasma-xdg-data-dirs.nix
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
