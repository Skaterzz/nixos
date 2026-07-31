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
    # ../../modules/nixos/plasma-xdg-data-dirs.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/virtualisation.nix
    ../../modules/nixos/users.nix

    # NOT imported: ../../modules/nixos/nvidia.nix
    #
    # That module hard-sets `services.xserver.videoDrivers = [ "nvidia" ]`
    # and configures a single always-on discrete GPU, which is right for the
    # desktop and wrong for most laptops. If this machine has no NVIDIA chip,
    # leave it out. If it's an NVIDIA Optimus hybrid, don't import it as-is
    # either — you want PRIME offload instead, roughly:
    #
    #   hardware.nvidia.prime = {
    #     offload.enable = true;
    #     offload.enableOffloadCmd = true;
    #     intelBusId = "PCI:0:2:0";    # from `lspci | grep -E 'VGA|3D'`
    #     nvidiaBusId = "PCI:1:0:0";
    #   };
    #
    # with `services.xserver.videoDrivers = [ "modesetting" "nvidia" ]`.
  ];

  networking.hostName = "laptop";

  # Bootloader, its theming and other-OS detection: modules/nixos/boot.nix.
  # Defaults to limine; `local.boot.loader = "systemd-boot";` is the way back
  # to what this host used before that module existed.

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "24.11";
}
