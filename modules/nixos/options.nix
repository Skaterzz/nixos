{ lib, ... }:

# System-level `local.*` options.
#
# The home-manager equivalents live in home/common/options.nix; these are the
# ones a NixOS module needs to read, which can't come from there.
{
  options.local.boot.loader = lib.mkOption {
    type = lib.types.enum [
      "limine"
      "grub"
      "systemd-boot"
    ];
    default = "limine";
    description = ''
      Which bootloader to install. See modules/nixos/boot.nix.

      "limine" is the default because it is the only one of the three that
      can draw the desktop's wallpaper and palette on the boot menu, which
      is the point of the module. It finds other operating systems by
      scanning the EFI System Partition for their boot loaders.

      "grub" is the fallback for anything limine can't handle — BIOS/MBR
      installs, exotic partition layouts, or a machine whose firmware
      dislikes limine's EFI binary. It detects other systems with os-prober,
      which looks *inside* other partitions rather than only at the ESP, so
      it finds installs whose loader isn't on this ESP at all. It is themed
      from the palette but its background is fixed at build time.

      "systemd-boot" is the escape hatch, and what this repo used before the
      module existed. No theming at all — it has no background support — but
      it is the most boring, best-tested option on a UEFI machine, and it
      picks up Windows on its own.

      Changing this rewrites how the machine boots. Do it on a rebuild you
      can watch, with install media to hand: the previous generation stays
      in the *old* loader's menu, but only if that loader is still installed
      and still the one the firmware runs.
    '';
  };

  options.local.boot.detectOtherSystems = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Add boot menu entries for other operating systems found on the machine.

      Under limine this scans the EFI System Partition for other vendors'
      boot loaders (Windows, another distro's GRUB or shim, rEFInd) and adds
      a chainload entry for each. Under grub it enables os-prober. Under
      systemd-boot it does nothing — that loader already finds Windows and
      any other Boot Loader Spec entries by itself.

      Detection runs against the mounted ESP only. An OS on a disk that
      isn't mounted here won't be seen; os-prober (grub) is the option that
      looks further.
    '';
  };

  options.local.boot.wallpaper = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = ''
      Image to show on the boot menu until a wallpaper has been picked in
      niri, and on hosts that don't run niri at all.

      The niri wallpaper always wins when the state file names a readable
      file — see the limine-theme-sync service in modules/nixos/boot.nix.
      null means no image, which limine treats as "draw the backdrop
      colour", not as an error.
    '';
  };

  options.local.boot.branding = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "gamestation";
    description = ''
      Text limine prints above the boot menu, in the theme's accent colour.
      null leaves limine's own branding alone. Ignored by the other loaders.
    '';
  };

  options.local.boot.menuTransparency = lib.mkOption {
    type = lib.types.strMatching "[0-9a-fA-F]{2}";
    default = "50";
    description = ''
      How much of the wallpaper shows through the limine menu panel, as the
      `TT` byte of limine's `term_background` (`TTRRGGBB`). "00" is an opaque
      panel in the theme's background colour — the wallpaper then only shows
      in the margin — and "ff" is fully transparent, which puts the menu text
      straight onto the picture and is usually unreadable.

      The default is a middle that keeps the text legible on a busy image.
    '';
  };

  options.local.sddm.theme = lib.mkOption {
    type = lib.types.enum [
      "stock"
      "astronaut"
    ];
    default = "stock";
    description = ''
      Which greeter SDDM draws.

      "stock" sets no theme at all, so SDDM uses its own built-in greeter:
      no external theme package, no QML of ours, no runtime state pointing
      at it. Almost nothing in that path is our code, which is exactly why
      it is the default.

      "astronaut" is the themed one — an sddm-astronaut build per palette,
      following the desktop's theme and wallpaper through a system service.

      The themed greeter left the primary display black on this machine.
      That happened under kwin_wayland, under weston and under X11 alike,
      with the display-server layer producing no errors at all: SDDM logged
      "Greeter session started successfully" and the greeter connected. Three
      different display servers failing identically points away from all of
      them and at the one component they share, which is the theme.

      So "stock" is both the fallback and the experiment. If the login screen
      works here, the theme was at fault and can be rebuilt more carefully.
      If it is still black, the cause is somewhere neither the compositor nor
      the theme, and the next thing to suspect is SDDM's multi-monitor
      handling itself.
    '';
  };

  options.local.sddm.wayland = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Run SDDM's Wayland greeter. False uses the X11 greeter instead, which
      starts an X server for the sole purpose of drawing the login screen.

      The niri session is Wayland either way — this is only about the greeter.

      True by default because X11 was tried against the black primary display
      and behaved exactly like the two Wayland compositors, which is what
      ruled the display server out as the cause. It stays an option because
      it is one line to flip and worth a try if the greeter breaks again.
    '';
  };

  options.local.sddm.compositor = lib.mkOption {
    type = lib.types.enum [
      "kwin"
      "weston"
    ];
    default = "kwin";
    description = ''
      Which compositor SDDM's Wayland greeter runs under.

      Back to NixOS's default of kwin. weston was tried against the black
      primary display and made no difference, which — together with X11
      behaving the same way — is what ruled the compositor out.

      Kept as an option because it is a cheap thing to vary if the greeter
      misbehaves again. To leave Wayland entirely, set
      `services.displayManager.sddm.wayland.enable = false` for the X11
      greeter; the niri session stays Wayland regardless.
    '';
  };
}
