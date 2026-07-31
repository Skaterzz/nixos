{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./kernel-params.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/desktop.nix
    # Workaround for nixpkgs#126590 (huge XDG_DATA_DIRS makes every app slow
    # to start). Rebuilds plasma-workspace from source — remove this import
    # if the build cost outweighs the win.
    ../../modules/nixos/plasma-xdg-data-dirs.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/users.nix

    # Development tooling: direnv, Docker, libvirtd/QEMU/virt-manager, and
    # the nix settings per-project dev shells need. Uncomment to enable.
    #
    # This is where Docker now lives — the old virtualisation.nix was folded
    # into it — so leaving it off means no containers on this host either.
    ../../modules/nixos/development.nix
  ];

  networking.hostName = "gamestation";

  # Bootloader, its theming and other-OS detection: modules/nixos/boot.nix.
  # Defaults to limine; `local.boot.loader = "systemd-boot";` is the way back
  # to what this host used before that module existed.

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "24.11";
}
