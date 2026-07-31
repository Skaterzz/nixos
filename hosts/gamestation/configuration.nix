{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix
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

  # Bootloader, its theming and other-OS detection: modules/nixos/boot.nix.
  # Defaults to limine; `local.boot.loader = "systemd-boot";` is the way back
  # to what this host used before that module existed.

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "24.11";
}
