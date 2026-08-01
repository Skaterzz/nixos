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

      Under limine this covers this machine's own ESP always, and every
      other EFI System Partition on the machine when
      `local.boot.scanAllEsps` is on. What neither reaches is an OS whose
      loader lives on a non-EFI partition — os-prober (grub) is the option
      that looks that far.
    '';
  };

  options.local.boot.scanAllEsps = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Look for other operating systems on *every* EFI System Partition
      attached to the machine, not just the one NixOS boots from. Only
      meaningful under limine, and only when
      `local.boot.detectOtherSystems` is on.

      This is what finds a Windows installed on its own disk. Sharing one
      ESP is the common case for a dual boot set up in a single sitting,
      and the plain scan handles that — but a second OS installed later, or
      onto a disk of its own, brings its own ESP, and NixOS does not mount
      it. So limine-theme-sync locates them by partition type, mounts each
      read-only in turn, reads it, and unmounts. Nothing is written and no
      mount outlives the scan.

      Entries found this way are addressed by filesystem UUID
      (`uuid(XXXX-XXXX):/EFI/...`) rather than limine's `boot():`, which
      only ever means the volume limine itself was loaded from.

      Turn this off if the extra mounts are unwelcome — on a machine with an
      encrypted or removable disk you'd rather nothing touched, or if a
      rebuild is somehow slowed by spinning something up.
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

  options.local.power.noAutoSleepOnAC = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Never suspend on an idle timer while the machine is on mains power.
      Battery behaviour is untouched.

      Implemented as a logind *idle* inhibitor held for as long as a mains
      supply is online — see modules/nixos/power.nix. That blocks the
      automatic, timer-driven path only: `systemctl suspend`, the session
      menu's "Suspend" and the lid switch all still work, which a `sleep`
      inhibitor would have broken.

      Locking, dimming and blanking are unaffected. Those are separate
      timers (swayidle under niri, powerdevil under Plasma) and "don't fall
      asleep" is not "don't lock the screen".

      Whether the machine counts as on mains is read from
      /sys/class/power_supply. A machine with no battery at all is always
      on mains, so the inhibitor simply stays up on the desk and the
      server.
    '';
  };

  options.local.backlight.ddcci.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Control external monitors' brightness over DDC/CI, by loading the
      out-of-tree ddcci-backlight driver. See modules/nixos/ddcci.nix.

      This is what makes brightnessctl — and anything else that drives
      `/sys/class/backlight` — work on a machine with no internal panel. Each
      monitor that answers DDC/CI gets a `ddcci*` backlight device, and the
      existing keybinds and idle dim then apply to it with no changes.

      Off by default because it is an out-of-tree kernel module, and because
      on a laptop it would add a second set of backlight devices whenever an
      external monitor is plugged in — which is only useful if you actually
      want the external displays following the brightness keys too.

      A monitor that ignores DDC/CI, or has it switched off in its OSD, simply
      doesn't get a device. Nothing else breaks.
    '';
  };

  options.local.backlight.ddcci.busNameMatch = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "NVIDIA i2c adapter*"
      "AMDGPU DM*"
      "Radeon i2c*"
      "i915 gmbus*"
    ];
    description = ''
      I2C adapter names to look for monitors on, as udev `ATTR{name}` globs.
      Only meaningful when `local.backlight.ddcci.enable` is on.

      Adapters are matched by name rather than probing every bus on the
      machine on purpose. A desktop's i2c buses are mostly *not* displays —
      they are SMBus segments carrying RAM SPD, fan controllers and RGB
      hardware — and this box already runs with `acpi_enforce_resources=lax`
      (hosts/gamestation/kernel-params.nix) so that OpenRGB can reach some of
      them. Sending display queries to those is not a thing worth doing on a
      timer at every boot.

      Note that these are the *display* adapters of each driver, not every bus
      the GPU exposes — an AMD card's "AMDGPU SMU" bus is RGB and telemetry,
      not a monitor, and is deliberately not in the list.

      If a monitor isn't picked up, get the real adapter names off the machine
      and add the one it is on:

          cat /sys/bus/i2c/devices/i2c-*/name
          ddcutil detect
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
