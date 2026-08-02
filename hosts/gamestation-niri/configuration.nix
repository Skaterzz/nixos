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

    # niri replaces plasmalogin.nix: it brings its own session, SDDM, portals,
    # audio and polkit agent.
    ../../modules/nixos/niri.nix
    ../../modules/nixos/desktop.nix

    # Fluent Emoji as the system emoji font. The picker that shows it off is
    # Mod+. — see home/joshr/niri/emoji.nix.
    ../../modules/nixos/emoji.nix

    ../../modules/nixos/nvidia.nix

    # Brightness keys for the two DisplayPort monitors. Nothing on this
    # machine has an internal panel, so /sys/class/backlight is empty and
    # brightnessctl has nothing to write — see modules/nixos/ddcci.nix.
    ../../modules/nixos/ddcci.nix

    ../../modules/nixos/gaming.nix
    ../../modules/nixos/users.nix
    ../../modules/nixos/default-apps.nix

    # Development tooling: direnv, Docker, and the nix settings per-project
    # dev shells need.
    #
    # This is where Docker lives — the old virtualisation.nix was folded into
    # it — so dropping this import means no containers on this host either.
    ../../modules/nixos/development.nix

    # QEMU/KVM guests and the virt-manager GUI. Split out of development.nix,
    # so containers and VMs are separate switches.
    ../../modules/nixos/virtualization.nix

    # NOT imported: ../../modules/nixos/plasma-xdg-data-dirs.nix
    #
    # That workaround exists because plasma-workspace's Qt wrapper builds an
    # ~18 KB XDG_DATA_DIRS. There is no plasma-workspace in a niri session, so
    # the bug it works around cannot occur here — and neither can the
    # from-source rebuild of plasma-workspace that the workaround costs.
  ];

  networking.hostName = "dialga";

  # DDC/CI brightness for the external monitors. Both displays get a
  # /sys/class/backlight/ddcci* device, which is what the XF86MonBrightness
  # keys and the swayidle dim have always been driving — they just had
  # nothing to drive here until now.
  local.backlight.ddcci.enable = true;

  # Themed login screen: one sddm-astronaut build per palette, following the
  # desktop's theme and wallpaper.
  #
  # This was black on the primary display for a while. The cause looks to have
  # been the theme pointing Background at a wallpaper file that doesn't exist
  # until the switcher has run, and feeding that to a blur shader — see "The
  # login screen" in MANUAL.md. If it comes back black, set this to "stock"
  # and rebuild; a TTY (Ctrl+Alt+F2) still works, as does the previous
  # generation in the boot menu.
  local.sddm.theme = "astronaut";

  # Bootloader, its theming and other-OS detection: modules/nixos/boot.nix.
  # Defaults to limine; `local.boot.loader = "systemd-boot";` is the way back
  # to what this host used before that module existed.

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "26.05";
}
