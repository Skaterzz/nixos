{ config, inputs, lib, pkgs, ... }:

# Which kernel the machine boots.
#
# Most hosts here have no opinion: NixOS picks nixpkgs' current stable Linux
# and that is what the laptop, the two servers and the stick run. This module
# exists for the desk, and all it does is swap that for the CachyOS kernel —
# mainline plus CachyOS's patch set, built with their kconfig, taken prebuilt
# from the `nix-cachyos-kernel` flake input.
#
# It is imported by hosts/gamestation/kernel-params.nix, which both desk hosts
# already share, so `gamestation` and `gamestation-niri` cannot end up on
# different kernels by editing one and forgetting the other. That would not
# break anything, but it would mean a kernel build every time the session
# changes, which rather defeats "switching is just a rebuild".
#
#
# What BORE actually changes
# --------------------------
#
# The default variant is BORE — Burst-Oriented Response Enhancer — which is a
# patch on top of the fair scheduler rather than a replacement for it. It
# keeps a per-task record of how bursty that task has been and uses it to bias
# who runs next, so short bursty work (a render thread waking sixty times a
# second, the compositor, an audio thread) gets picked over a long-running
# batch job holding the same nice value. On a box that plays a game while an
# ollama, a Docker build and a browser are resident, that is the difference it
# makes.
#
# **It is a floor being raised, not a bug being found.** A scheduler swap is
# not the answer to "this was faster last month": something that got slower
# got slower *because* something changed, and on this machine the things that
# change are the driver, the shader cache, and whatever else is holding video
# memory. `gaming-doctor` (modules/nixos/gaming.nix) prints all three in one
# go and "Gaming performance" in MANUAL.md reads the output. Run that first;
# this module is worth having either way, but it will not undo a regression it
# had nothing to do with.
#
#
# How the kernel gets here
# ------------------------
#
# The flake input exposes an overlay that adds one attribute, `cachyosKernels`,
# holding a `linuxPackages-cachyos-<variant>` set per variant. `overlays.pinned`
# is the one applied below rather than `overlays.default`: pinned builds those
# sets from the *flake's own* nixpkgs revision, which is the revision its Hydra
# built and cached them at. `default` would rebuild them against this flake's
# nixpkgs, which is a different derivation hash for every kernel in the set and
# therefore a local compile. The same reasoning is why the input does not
# `follows` our nixpkgs — see the comment on it in flake.nix.
#
# What follows the kernel out of that pinned set is everything reached through
# `config.boot.kernelPackages`:
#
#   * the NVIDIA driver. modules/nixos/nvidia.nix asks for
#     `kernelPackages.nvidiaPackages.latest`, so on these hosts the driver and
#     its kernel module come from the kernel flake's nixpkgs rather than ours.
#     That combination — this variant, `latest`, `open = true` — is one the
#     flake builds in its own CI, so it is cached rather than compiled.
#
#   * the DDC/CI module on gamestation-niri (modules/nixos/ddcci.nix, via
#     `kernelPackages.ddcci-driver`). Out-of-tree and small; it builds locally
#     in well under a minute, and it follows the kernel's compiler by itself if
#     an LTO variant is ever selected.
#
# Nothing else in this repository reaches into `boot.kernelPackages`, and no
# host here uses ZFS — which is the other module that would have to be pointed
# at the CachyOS build (`boot.zfs.package = kernelPackages.zfs_cachyos`) if one
# ever did.
#
#
# The first rebuild
# -----------------
#
# The substituter below is installed *by* a rebuild, and the nix-daemon doing
# that rebuild is still running on the old configuration — so the switch that
# introduces both the cache and the kernel is exactly the one that cannot use
# the cache, and it will happily spend an hour compiling instead. Pass them on
# the command line for that one rebuild:
#
#     sudo nixos-rebuild switch --flake .#gamestation \
#       --option extra-substituters https://attic.xuyh0120.win/lantian \
#       --option extra-trusted-public-keys lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=
#
# Every rebuild after that reads it from /etc/nix/nix.conf. If one starts
# building a kernel anyway, the input has moved ahead of what the cache holds:
# `nix flake update nix-cachyos-kernel` again in a day, or ride it out.
#
#
# Getting back
# ------------
#
# `nixos-rebuild test` is no help for a kernel — it activates the new system
# without a boot entry, and the running kernel is not something activation can
# replace. The way back is the previous generation in the boot menu, which is
# also why `local.boot.maxGenerations` matters more once this is on. Setting
# `local.kernel.cachyos.enable = false` and rebuilding returns to the nixpkgs
# kernel from a working session.
let
  cfg = config.local.kernel.cachyos;
in
{
  # local.* lives in its own module so this one can stay a config attrset.
  imports = [ ./options.nix ];

  config = lib.mkMerge [
    {
      # Applied whether or not the kernel is switched on, and left out of the
      # `mkIf` below deliberately. It adds exactly one attribute, evaluated
      # lazily and referred to by nothing else here, so there is no cost to
      # gate — and keeping `nixpkgs.overlays` a plain list keeps the
      # construction of `pkgs` from having to read an option this same module
      # declares, which is the shape that turns into an infinite recursion the
      # first time somebody makes the condition slightly cleverer.
      nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
    }

    # Also not gated on `enable`, and for a reason of its own. A host that
    # imports this module wants this kernel eventually, and the cache being
    # already in place is what makes turning it on — or back on — an ordinary
    # rebuild rather than an hour of compiling. See the option's description
    # for the trust this extends, and the note above for why the very first
    # rebuild still needs the flags on the command line.
    (lib.mkIf cfg.binaryCache.enable {
      nix.settings = {
        # Both lists merge with nixpkgs' own definitions rather than replacing
        # them — cache.nixos.org is added with `mkAfter` in
        # nixos/modules/config/nix.nix, so it stays, behind this one.
        substituters = [ "https://attic.xuyh0120.win/lantian" ];
        trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
      };
    })

    (lib.mkIf cfg.enable {
      boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-${cfg.variant}";
    })
  ];
}
