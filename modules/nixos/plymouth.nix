{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# The boot splash: an animation over the gap between the boot menu and the
# login screen, instead of a wall of kernel messages.
#
# Imported by modules/nixos/boot.nix so the option exists wherever the
# bootloader module does, and gated on `local.boot.plymouth.enable`, which is
# off unless a host says otherwise. The graphical hosts say otherwise; the two
# servers deliberately don't — a machine that reboots unattended and is only
# ever seen over SSH has nobody to show a splash to, and hiding its console
# output is the opposite of useful when it doesn't come back.
#
#
# The theme, and its confusing name
# ---------------------------------
#
# `mac-style`, from SergioRibera/s4rchiso-plymouth-theme: the NixOS logo over
# black with a progress bar under it, paced like a Mac's boot animation.
#
# The repository name is historical and does not describe what is installed
# here. It began as an Arch theme — an animated Arch logo, still on the
# `archlinux` branch — and its default branch `nix` is now a flake carrying a
# NixOS-logo theme called `mac-style`. That branch's README is the
# installation instructions this module follows, so what arrives is the NixOS
# animation and not the Arch one, whatever the input is called.
#
# It is packaged upstream (`package.nix` on that branch), which is why there
# is no derivation here: the flake exposes an overlay adding
# `pkgs.mac-style-plymouth`, and that is the package NixOS is handed below.
#
# The overlay is applied *here* rather than in flake.nix, for the same reason
# nvidia-patch's is applied in modules/nixos/nvidia-server.nix: an overlay
# named in flake.nix would reach every host, and this one should only reach
# the hosts that draw a splash. The README's own snippet applies it at the
# `import nixpkgs` in flake.nix, which is the shape of that instruction and
# not a requirement of the overlay — `nixpkgs.overlays` composes the same way
# from inside a module.
#
# Unlike the Arch theme on the other branch, this one is built on plymouth's
# `two-step` module, which knows how to draw a password dialog. So a machine
# with an encrypted root still gets somewhere to type: the prompt appears over
# the animation rather than being hidden by it.
let
  cfg = config.local.boot.plymouth;
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ inputs.mac-style-plymouth.overlays.default ];

    boot.plymouth = {
      enable = true;
      theme = "mac-style";
      themePackages = [ pkgs.mac-style-plymouth ];
    };

    # Quieting the boot is a separate switch because it is a separate decision:
    # the splash draws either way, and these lines are about what is allowed to
    # scribble over it.
    #
    # Plymouth owns the framebuffer console from the initrd onwards, but the
    # kernel writes to it directly and outranks anything in userspace — one
    # printk at the wrong log level and the animation is sitting under a driver
    # message for the rest of the boot. So the messages have to be turned down
    # rather than covered up:
    #
    #   quiet                 the kernel's own switch: only KERN_ERR and worse
    #                         reach the console. `splash` alongside it is the
    #                         flag plymouth's initrd hook looks for.
    #   consoleLogLevel = 0   the same limit, as the `loglevel=` parameter
    #                         NixOS generates from it.
    #   udev.log_level=3      udev is the loudest thing in the initrd and is
    #                         not covered by the kernel's own limit; the `rd.`
    #                         form is the initrd's copy of the same setting.
    #   initrd.verbose        NixOS's own switch for the stage-1 script's
    #                         progress messages.
    #
    # `boot.kernelParams` is a list option, so this merges with whatever a host
    # already sets — hosts/gamestation/kernel-params.nix and the laptop's
    # `mem_sleep_default=deep` are untouched by it.
    boot.kernelParams = lib.mkIf cfg.quiet [
      "quiet"
      "splash"
      "udev.log_level=3"
      "rd.udev.log_level=3"
    ];

    boot.consoleLogLevel = lib.mkIf cfg.quiet 0;
    boot.initrd.verbose = lib.mkIf cfg.quiet false;
  };
}
