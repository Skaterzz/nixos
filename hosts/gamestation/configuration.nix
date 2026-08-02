{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./kernel-params.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/plasmalogin.nix
    ../../modules/nixos/desktop.nix
    # Fluent Emoji as the system emoji font. Plasma's own picker is already
    # on Meta+. — see home/joshr/plasma.nix.
    ../../modules/nixos/emoji.nix
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

    # NOT imported: ../../modules/nixos/virtualization.nix
    #
    # QEMU/KVM guests live on the niri variant of this box, which is where
    # single GPU passthrough is turned on too. To have both here as well, add
    # that import and the option it carries:
    #
    #     local.virtualisation.singleGpuPassthrough = {
    #       enable = true;
    #       vms = [ "<domain name>" ];
    #     };
    #
    # Everything else it needs is already on this host: the IOMMU flags in
    # ./kernel-params.nix, and one display manager for the hook to stop.
  ];

  networking.hostName = "dialga";

  # Bootloader, its theming and other-OS detection: modules/nixos/boot.nix.
  # Defaults to limine; `local.boot.loader = "systemd-boot";` is the way back
  # to what this host used before that module existed.

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "26.05";
}
