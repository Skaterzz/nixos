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

    # niri replaces desktop.nix.
    ../../modules/nixos/niri.nix

    ../../modules/nixos/laptop.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/virtualisation.nix
    ../../modules/nixos/users.nix

    # NOT imported: plasma-xdg-data-dirs.nix — there is no plasma-workspace
    # in a niri session, so nixpkgs#126590 can't bite here.
    #
    # NOT imported: nvidia.nix — see hosts/laptop/configuration.nix for the
    # PRIME-offload notes if this machine has an NVIDIA chip.
  ];

  networking.hostName = "laptop";

  # Themed login screen, same as the desk. See
  # hosts/gamestation-niri/configuration.nix and "The login screen" in the
  # README for the black-greeter history behind this being an option at all.
  # Set to "stock" for SDDM's built-in greeter if it ever misbehaves here.
  local.sddm.theme = "astronaut";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "24.11";
}
