{ config, inputs, lib, pkgs, ... }:

# Which kernel the machine boots.
#
# Most hosts here have no opinion: NixOS picks nixpkgs' current stable Linux
# and that is what the two servers and the stick run. This module
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
# Never compiling it
# ------------------
#
# Compiling a CachyOS kernel on the desk is the better part of an hour, and
# every part of this arrangement exists to make sure it never happens. Four
# things have to hold, and all four are load-bearing:
#
#   * **The cache has to be configured before the build is planned, not by
#     it.** The `nix.settings` below are installed *by* a rebuild, and the
#     daemon running that rebuild is still on the old configuration — so on
#     the switch that first introduces the kernel they are useless. What
#     covers that gap is `nixConfig` at the top of flake.nix, which nix reads
#     off the flake it is being asked to build, before any of this. It asks
#     once per user before honouring it; `--accept-flake-config` skips the
#     question. The two copies have to say the same thing and nothing checks
#     that they do — see the comment there.
#
#   * **The kernel has to be the derivation the cache holds.** That is what
#     `overlays.pinned` buys: the package set is built from the kernel flake's
#     own nixpkgs, the revision its CI built at. `overlays.default` would
#     rebuild it against ours, which is a different hash and therefore a
#     local compile, and so would `inputs.nixpkgs.follows` on the input.
#     Neither is used. Our `nixpkgs.config` doesn't reach it either, for the
#     same reason — the kernel isn't built from our pkgs at all.
#
#   * **The input has to name a kernel that has actually been built.** The
#     `release` branch only moves once the flake's Hydra has built and pushed
#     what it names; `master` can name one that exists nowhere yet.
#
#   * **The variant has to be one of the ones they build.** That is what the
#     enum on `local.kernel.cachyos.variant` is for.
#
# Checking rather than hoping, before committing an hour to a switch:
#
#     # succeeds only if the kernel can be fetched; --max-jobs 0 forbids
#     # building anything locally, so a cache miss is an error rather than
#     # a long wait
#     nix build --max-jobs 0 --no-link \
#       .#nixosConfigurations.gamestation.config.boot.kernelPackages.kernel
#
#     # the whole system: what would be fetched, and what would be built
#     nixos-rebuild dry-build --flake .#gamestation
#
# Two things do still compile here and both are expected. The DDC/CI module
# on gamestation-niri is out-of-tree and takes well under a minute. And the
# NVIDIA kernel module is only prebuilt for the variants the kernel flake
# assembles a whole test system for — latest, lts, bore, and their `-lto`
# twins — so a `-x86_64-v3` or `-zen4` kernel arrives cached but its driver
# module does not, and that is ten minutes rather than an hour.
#
# If a rebuild starts building a kernel anyway, the input has moved ahead of
# what the cache holds: `git checkout flake.lock` and try the update again in
# a day, or ride it out.
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
    # for the trust this extends.
    #
    # This is the permanent copy, in /etc/nix/nix.conf, read by every rebuild
    # and by anything else on the machine that talks to the daemon. The
    # temporary one is `nixConfig` in flake.nix, which covers the rebuild that
    # installs this — keep the two in step, because nothing else will.
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
