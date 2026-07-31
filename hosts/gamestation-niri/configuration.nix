{ config, lib, pkgs, ... }:

# The same physical machine as `gamestation`, running niri instead of Plasma.
#
#   sudo nixos-rebuild switch --flake .#gamestation-niri   # try niri
#   sudo nixos-rebuild switch --flake .#gamestation        # go back to Plasma
#
# Nothing is destroyed by switching either way, and the previous generation is
# always in the boot menu.
#
# It's a separate host rather than a toggle inside `gamestation` because the
# two configure *different display managers* — Plasma uses
# plasma-login-manager and niri uses SDDM — and NixOS won't let both be
# enabled at once.
{
  imports = [
    # Same machine, so the same hardware scan and the same kernel command
    # line — both live under ../gamestation/ and are shared by the two hosts.
    ../gamestation/hardware-configuration.nix
    ../gamestation/kernel-params.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix

    # niri replaces desktop.nix: it brings its own session, SDDM, portals,
    # audio and polkit agent.
    ../../modules/nixos/niri.nix

    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/users.nix
    ../../modules/nixos/office.nix
    ../../modules/nixos/contentcreation.nix

    # Development tooling: direnv, Docker, libvirtd/QEMU/virt-manager, and
    # the nix settings per-project dev shells need. Uncomment to enable.
    #
    # This is where Docker now lives — the old virtualisation.nix was folded
    # into it — so leaving it off means no containers on this host either.
    # ../../modules/nixos/development.nix

    # NOT imported: ../../modules/nixos/plasma-xdg-data-dirs.nix
    #
    # That workaround exists because plasma-workspace's Qt wrapper builds an
    # ~18 KB XDG_DATA_DIRS. There is no plasma-workspace in a niri session, so
    # the bug it works around cannot occur here — and neither can the
    # from-source rebuild of plasma-workspace that the workaround costs.
  ];

  networking.hostName = "dialga";

  # Themed login screen: one sddm-astronaut build per palette, following the
  # desktop's theme and wallpaper.
  #
  # This was black on the primary display for a while. The cause looks to have
  # been the theme pointing Background at a wallpaper file that doesn't exist
  # until the switcher has run, and feeding that to a blur shader — see "The
  # login screen" in the README. If it comes back black, set this to "stock"
  # and rebuild; a TTY (Ctrl+Alt+F2) still works, as does the previous
  # generation in the boot menu.
  local.sddm.theme = "astronaut";

  # Bootloader, its theming and other-OS detection: modules/nixos/boot.nix.
  # Defaults to limine; `local.boot.loader = "systemd-boot";` is the way back
  # to what this host used before that module existed.

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "26.05";
}
