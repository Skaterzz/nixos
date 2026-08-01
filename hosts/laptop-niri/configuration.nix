{ config, lib, pkgs, ... }:

# The same physical machine as `laptop`, running niri instead of Plasma.
#
#   sudo nixos-rebuild switch --flake .#laptop-niri   # try niri
#   sudo nixos-rebuild switch --flake .#laptop        # go back to Plasma
#
# See hosts/gamestation-niri/configuration.nix for why this is a separate
# host rather than a toggle.
{
  imports = [
    ../laptop/hardware-configuration.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix

    # niri replaces plasmalogin.nix.
    ../../modules/nixos/niri.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/default-apps.nix

    # Fluent Emoji as the system emoji font. The picker that shows it off is
    # Mod+. — see home/joshr/niri/emoji.nix.
    ../../modules/nixos/emoji.nix

    ../../modules/nixos/laptop.nix
    #../../modules/nixos/gaming.nix
    ../../modules/nixos/users.nix

    # Development tooling: direnv, Docker, libvirtd/QEMU/virt-manager, and
    # the nix settings per-project dev shells need. Uncomment to enable.
    #
    # This is where Docker now lives — the old virtualisation.nix was folded
    # into it — so leaving it off means no containers on this host either.
    # ../../modules/nixos/development.nix

    # NOT imported: plasma-xdg-data-dirs.nix — there is no plasma-workspace
    # in a niri session, so nixpkgs#126590 can't bite here.
    #
    # NOT imported: nvidia.nix — see hosts/laptop/configuration.nix for the
    # PRIME-offload notes if this machine has an NVIDIA chip.
  ];

  networking.hostName = "wooper";

  # Themed login screen, same as the desk. See
  # hosts/gamestation-niri/configuration.nix and "The login screen" in the
  # README for the black-greeter history behind this being an option at all.
  # Set to "stock" for SDDM's built-in greeter if it ever misbehaves here.
  local.sddm.theme = "astronaut";

  # Bootloader, its theming and other-OS detection: modules/nixos/boot.nix.
  # Defaults to limine; `local.boot.loader = "systemd-boot";` is the way back
  # to what this host used before that module existed.

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "26.05";
}
