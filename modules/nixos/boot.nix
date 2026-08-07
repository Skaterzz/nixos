{ config, lib, pkgs, ... }:

# Bootloader: which one is installed, how it finds other operating systems,
# and — for limine — how the boot menu follows the desktop's theme.
#
# `local.boot.loader` picks between three, described in modules/nixos/options.nix.
# Only one is ever enabled; NixOS refuses to install two.
#
# What happens *after* the menu — the plymouth splash covering the boot — is
# modules/nixos/plymouth.nix, imported below so that `local.boot.plymouth.*`
# exists on every host this module does. It is off unless a host turns it on.
#
#
# Finding other operating systems
# -------------------------------
#
# On by default — `local.boot.detectOtherSystems`. Under limine the scan runs
# in two passes, both inside limine-theme-sync below:
#
#   * this machine's own ESP, walked directly. That is the whole story for a
#     dual boot where both systems share one EFI System Partition, which is
#     what you get installing them onto the same disk.
#
#   * every other ESP attached to the machine, gated behind
#     `local.boot.scanAllEsps`. NixOS mounts exactly one ESP, so an OS
#     installed onto a disk of its own is otherwise invisible; each is found
#     by GPT partition type, mounted read-only, read, and unmounted.
#
# Each vendor directory holding a recognised loader becomes one chainload
# entry under an "Other operating systems" branch. To see what it found
# without rebooting:
#
#   sudo systemctl start limine-theme-sync
#   grep -A100 'detected systems' /boot/limine/limine.conf
#
# What neither pass reaches is an OS whose loader isn't on any ESP at all.
# That is what grub's os-prober is for — it inspects other *partitions* — so
# `local.boot.loader = "grub"` is the escape hatch, at the cost of the
# runtime theming.
#
#
# How limine ends up wearing the desktop's colours
# ------------------------------------------------
#
# The boot menu is drawn before any of the desktop exists, from a plain text
# file on the EFI System Partition. So the palette has to be *pushed* there
# ahead of time, the same way the SDDM greeter is fed in
# modules/nixos/niri.nix — and for the same reason: the thing being themed
# can't read joshr's home directory, or anything else that isn't the ESP.
#
# What gets pushed is Noctalia's resolved palette manifest, not the name of a
# theme. That distinction is the whole of this module's history with the
# feature: a name only ever described one of Noctalia's four palette sources,
# and the other three — builtin, wallpaper-derived, community — have no name
# a Nix derivation could have been built against.
#
# The NixOS limine module generates `<esp>/limine/limine.conf` on every
# `nixos-rebuild`, so a runtime edit can't just be dropped anywhere in it. What
# makes this work is that the module emits two verbatim blocks under our
# control, at known ends of the file:
#
#   boot.loader.limine.extraConfig    first thing in the file, before limine's
#                                     own global options
#   boot.loader.limine.extraEntries   last thing in the file, after the NixOS
#                                     menu entries
#
# Both get a sentinel-delimited region, filled at build time with the *default*
# theme and no detected systems. `limine-theme-sync` then rewrites the inside of
# each region in place. If it never runs, the boot menu is still valid and still
# themed — just with the default palette — which is the failure mode you want
# from something standing between you and a bootable machine.
#
# The regions land where they do for a reason. limine's config has no separator
# between global options and menu entries: an entry is opened by a line starting
# with `/` and swallows every option after it. Theming keys are global, so they
# must go at the top, above the first entry; detected-OS entries must go at the
# bottom, below the NixOS ones. Swapping them would make limine read our
# `timeout` and `default_entry` as belonging to a Windows entry.
#
# Three things have to be true for the rewrite to be safe, and all three are
# enforced below:
#
#   * `enrollConfig` stays off. Enrolling hashes the config into the limine
#     binary; a rewritten file then fails its own integrity check and the
#     machine stops at the bootloader. This is the one setting here that turns
#     a cosmetic feature into an unbootable system.
#   * The wallpaper lives *outside* `<esp>/limine/`. The installer walks that
#     directory and deletes every file it didn't itself write, so an image
#     parked there survives exactly until the next rebuild.
#   * The config never names a wallpaper that isn't there. Both the build-time
#     block and the sync emit the `wallpaper:` line only alongside a file that
#     exists.
#
# `style.wallpapers` and the `style.graphicalTerminal.*` options are deliberately
# left alone. They would write the same keys we write, from build-time values,
# producing duplicates of every line — and `style.wallpapers` additionally
# appends a BLAKE2b hash of the image to the path, which is precisely what
# stops a file from being swapped underneath it at runtime.
let
  cfg = config.local.boot;

  themeSet = import ../../home/joshr/niri/themes.nix { inherit lib; };
  inherit (themeSet) themes;

  esp = config.boot.loader.efi.efiSysMountPoint;

  # The palette manifest Noctalia renders from its colour roles (the
  # `system_palette` user template in home/joshr/niri/noctalia.nix). The same
  # file the SDDM sync in niri.nix reads, with the same owner —
  # `local.desktop.primaryUser`, which is joshr unless a host says otherwise.
  niriStateDir = "/home/${config.local.desktop.primaryUser}/.local/state/niri-theme";
  resolvedThemeFile = "${niriStateDir}/noctalia-resolved";

  # Outside `<esp>/limine/` — see the header note about the installer's
  # delete-what-I-didn't-write pass over that directory.
  espSubdir = "niri-theme";
  espThemeDir = "${esp}/${espSubdir}";
  espWallpaper = "${espThemeDir}/wallpaper.png";

  limineConf = "${esp}/limine/limine.conf";

  # limine wants bare RRGGBB; themes.nix stores CSS "#rrggbb".
  hex = c: lib.toUpper (lib.removePrefix "#" c);

  # Same fallback as home/joshr/niri/theming.nix, for a theme defined without
  # an `ansi` block. Flat — the ten roles have no blue, magenta or cyan — but
  # it keeps adding a theme from breaking the bootloader.
  deriveAnsi = t: {
    black = t.bg;          brightBlack = t.fgDim;
    red = t.err;           brightRed = t.err;
    green = t.accent;      brightGreen = t.accent;
    yellow = t.warn;       brightYellow = t.warn;
    blue = t.accentDim;    brightBlue = t.accent;
    magenta = t.accentDim; brightMagenta = t.accent;
    cyan = t.accentDim;    brightCyan = t.accent;
    white = t.fg;          brightWhite = t.fg;
  };

  # limine's palettes are `;`-separated and positional: black, red, green,
  # brown, blue, magenta, cyan, gray — then the eight bright variants.
  palette = a: lib.concatMapStringsSep ";" hex [
    a.black a.red a.green a.yellow a.blue a.magenta a.cyan a.white
  ];
  brightPalette = a: lib.concatMapStringsSep ";" hex [
    a.brightBlack a.brightRed a.brightGreen a.brightYellow
    a.brightBlue a.brightMagenta a.brightCyan a.brightWhite
  ];

  # Colours only. The wallpaper lines are added separately, by whichever side
  # can see whether the image actually exists.
  themeBlock =
    t:
    let
      a = t.ansi or (deriveAnsi t);
    in
    lib.concatStringsSep "\n" (
      [
        # `backdrop` only shows with wallpaper_style: centered, so it is inert
        # as configured — but it is what fills the screen if the wallpaper is
        # ever missing or switched to centered, and the theme's background is
        # a better answer there than limine's grey.
        "backdrop: ${hex t.bg}"
        "term_foreground: ${hex t.fg}"
        "term_foreground_bright: ${hex t.accent}"
        # TTRRGGBB — TT is transparency, not alpha. See local.boot.menuTransparency.
        "term_background: ${lib.toUpper cfg.menuTransparency}${hex t.bg}"
        "term_background_bright: ${hex t.bgAlt}"
        "term_palette: ${palette a}"
        "term_palette_bright: ${brightPalette a}"
        "interface_branding_colour: ${hex t.accent}"
        "interface_help_colour: ${hex t.fgDim}"
        "interface_help_colour_bright: ${hex t.accent}"
      ]
      ++ lib.optional (cfg.branding != null) "interface_branding: ${cfg.branding}"
    );

  # The one rendered block that is not read from the manifest.
  #
  # This used to be a directory of them — one file per palette in themes.nix
  # plus one per Noctalia builtin — which the sync indexed by the name in
  # `~/.local/state/niri-theme/current`. Under Noctalia that lookup can never
  # hit: the shell writes `noctalia-live` there, deliberately, because a
  # wallpaper-derived or community palette has no name a Nix derivation could
  # have been built for. Every run therefore fell through to the default and
  # the boot menu wore it regardless of the desktop.
  #
  # What is left is that fallback, and only that: the palette the machine is
  # built with, for the first boot before Noctalia has written a manifest, and
  # for the Plasma hosts that never write one at all.
  defaultBlock = pkgs.writeText "limine-default-theme.conf" (themeBlock defaultTheme);

  wallpaperLines = ''
    wallpaper: boot():/${espSubdir}/wallpaper.png
    wallpaper_style: stretched'';

  # Replaces the lines between two marker lines with the contents of `src`,
  # leaving the markers themselves in place. A file missing the markers comes
  # through untouched.
  #
  # In its own file rather than inline in the sync script below because an awk
  # program is full of `$0`/`$1`, and shellcheck — which writeShellApplication
  # runs, and fails the build on — reads those as unexpanded shell variables.
  regionAwk = pkgs.writeText "limine-replace-region.awk" ''
    $0 == b { print; while ((getline line < src) > 0) print line; close(src); inside = 1; next }
    $0 == e { inside = 0 }
    !inside { print }
  '';

  themeBegin = "# >>> niri theme — rewritten by limine-theme-sync >>>";
  themeEnd = "# <<< niri theme <<<";
  entriesBegin = "# >>> detected systems — rewritten by limine-theme-sync >>>";
  entriesEnd = "# <<< detected systems <<<";

  # Mirrors the desktop's palette onto the ESP, and re-scans for other
  # operating systems.
  #
  # Runs at three moments, which between them cover every way the inputs can
  # change: at boot, whenever the session's palette changes (a path unit
  # watches the manifest), and at the end of every bootloader install, so a
  # rebuild doesn't leave the menu on the default palette until the next
  # reboot — the install rewrites limine.conf from `extraConfig`, which is the
  # build-time block, so without that third moment every rebuild would undo
  # this until something else woke it.
  limineSync = pkgs.writeShellApplication {
    name = "limine-theme-sync";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gawk
      gnused
      # lsblk, blkid, findmnt, mount, umount — for the other-ESP scan.
      util-linux
    ];
    text = ''
      conf="${limineConf}"

      # Nothing to theme until limine has been installed at least once. This is
      # the normal state on the rebuild that first switches the loader over, and
      # on any host using grub or systemd-boot.
      [ -f "$conf" ] || exit 0

      # --- wallpaper ----------------------------------------------------
      #
      # Left off. `local.boot.wallpaper` still seeds an image onto the ESP at
      # build time (`additionalFiles` below) and the sync still names it if it
      # is there, but the session's own wallpaper is no longer mirrored: on a
      # FAT partition shared with the firmware, a fresh 1080p PNG written on
      # every wallpaper change is a lot of churn for a screen that is up for
      # two seconds.
      #
      # The `install -d` that used to stand here is gone with it. Nothing after
      # this point writes into that directory, and `install -d` also chmods —
      # which on a vfat ESP mounted with a restrictive dmask fails outright,
      # and under `set -e` took the palette rewrite below down with it.

      body="$(mktemp)"
      entries="$(mktemp)"

      # scan_mount is set while another ESP is mounted below. Unmounting it
      # from the trap rather than only on the happy path matters because this
      # script also runs from limine's extraInstallCommands, outside any
      # systemd sandbox — a mount leaked there would outlive the rebuild and
      # pin a disk the user thinks is idle.
      scan_mount=""
      cleanup() {
        if [ -n "$scan_mount" ]; then
          umount "$scan_mount" 2>/dev/null || true
          rmdir "$scan_mount" 2>/dev/null || true
        fi
        rm -f "$body" "$entries"
      }
      trap cleanup EXIT

      # --- palette ------------------------------------------------------
      #
      # Noctalia's manifest is the authority whenever it is there and complete.
      # It is the only input that can describe a wallpaper-derived or community
      # palette, i.e. one created long after this NixOS generation was built,
      # and it describes a custom or builtin one in exactly the same lines.
      read_colour() {
        [ -f ${resolvedThemeFile} ] || return 0
        sed -n "s/^$1=\\(#[0-9A-Fa-f]\\{6\\}\\)$/\\1/p" ${resolvedThemeFile} | head -n1 || true
      }
      rgb() {
        printf '%s' "''${1#\#}" | tr '[:lower:]' '[:upper:]'
      }

      bg="$(read_colour bg)"
      bg_alt="$(read_colour bg_alt)"
      fg="$(read_colour fg)"
      fg_dim="$(read_colour fg_dim)"
      accent="$(read_colour accent)"
      live_palette=""
      live_bright_palette=""
      palette_ok=1

      for number in $(seq 0 15); do
        value="$(read_colour "color$number")"
        if [ -z "$value" ]; then
          palette_ok=0
          break
        fi
        value="$(rgb "$value")"
        if [ "$number" -lt 8 ]; then
          [ -z "$live_palette" ] || live_palette="$live_palette;"
          live_palette="$live_palette$value"
        else
          [ -z "$live_bright_palette" ] || live_bright_palette="$live_bright_palette;"
          live_bright_palette="$live_bright_palette$value"
        fi
      done

      if [ -n "$bg" ] && [ -n "$bg_alt" ] && [ -n "$fg" ] \
         && [ -n "$fg_dim" ] && [ -n "$accent" ] && [ "$palette_ok" -eq 1 ]; then
        {
          printf 'backdrop: %s\n' "$(rgb "$bg")"
          printf 'term_foreground: %s\n' "$(rgb "$fg")"
          printf 'term_foreground_bright: %s\n' "$(rgb "$accent")"
          printf 'term_background: %s%s\n' ${lib.escapeShellArg (lib.toUpper cfg.menuTransparency)} "$(rgb "$bg")"
          printf 'term_background_bright: %s\n' "$(rgb "$bg_alt")"
          printf 'term_palette: %s\n' "$live_palette"
          printf 'term_palette_bright: %s\n' "$live_bright_palette"
          printf 'interface_branding_colour: %s\n' "$(rgb "$accent")"
          printf 'interface_help_colour: %s\n' "$(rgb "$fg_dim")"
          printf 'interface_help_colour_bright: %s\n' "$(rgb "$accent")"
          ${lib.optionalString (cfg.branding != null) "printf '%s\\n' ${lib.escapeShellArg "interface_branding: ${cfg.branding}"}"}
        } > "$body"
      else
        # No manifest, or one missing a colour. The seven roles and all
        # sixteen terminal colours or none of them: a half-read manifest
        # producing a menu with the desktop's background and the build-time
        # palette's foreground is worse than one that is simply out of date.
        cp ${defaultBlock} "$body"
      fi

      # Only name the image if it is actually there — on a host that has never
      # picked a wallpaper and sets no local.boot.wallpaper, there is nothing
      # to point at and limine should be left to draw the backdrop colour.
      if [ -f "${espWallpaper}" ]; then
        printf '%s\n' ${lib.escapeShellArg wallpaperLines} >> "$body"
      fi

      # --- other operating systems --------------------------------------
      ${lib.optionalString cfg.detectOtherSystems ''
        # Bound here rather than at the top of the script because this is the
        # only section that reads it. writeShellApplication lints the script
        # at build time and fails on SC2034 (unused variable), so binding it
        # unconditionally would break the build for any host that sets
        # detectOtherSystems = false.
        esp="${esp}"

        # Labels already emitted, as "|Label|" runs. An OS whose loader
        # appears on two ESPs — a Windows recovery copy, a distro reinstalled
        # onto a second disk — is listed once, from whichever partition was
        # read first. That ordering is deliberate: this machine's own ESP is
        # scanned before any other, so a shared-ESP install always wins.
        seen_labels=""

        # Walk one mounted EFI System Partition and print a limine entry for
        # every vendor directory on it that carries a boot loader.
        #
        #   $1  where it is mounted
        #   $2  limine volume specifier to address paths on it, e.g.
        #       "boot():" or "uuid(1A2B-3C4D):"
        scan_root() {
          local root="$1" volume="$2"
          local dir vendor target cand label rel

          [ -d "$root/EFI" ] || return 0

          for dir in "$root"/EFI/*/; do
            [ -d "$dir" ] || continue

            vendor="$(basename "$dir")"
            case "''${vendor,,}" in
              # Ours, or not an operating system. BOOT is the removable-media
              # fallback path, which on this machine is limine's own copy.
              boot | limine | systemd | nixos | tools | memtest86) continue ;;
            esac

            # First match wins, so a distro shipping both shim and grub is
            # listed once. shim first: it is what boots under Secure Boot, and
            # it hands over to that distro's grub by itself.
            target=""
            for cand in bootmgfw.efi shimx64.efi grubx64.efi grubia32.efi \
                        refind_x64.efi elilo.efi bootx64.efi; do
              # -iname because the ESP is FAT and vendors disagree about case;
              # depth 2 because Windows keeps its loader in a Boot/ subdirectory.
              target="$(find "$dir" -maxdepth 2 -type f -iname "$cand" -print -quit 2>/dev/null || true)"
              [ -n "$target" ] && break
            done
            [ -n "$target" ] || continue

            case "''${vendor,,}" in
              microsoft) label="Windows Boot Manager" ;;
              ubuntu)    label="Ubuntu" ;;
              debian)    label="Debian" ;;
              fedora)    label="Fedora" ;;
              arch)      label="Arch Linux" ;;
              manjaro)   label="Manjaro" ;;
              pop)       label="Pop!_OS" ;;
              linuxmint) label="Linux Mint" ;;
              opensuse)  label="openSUSE" ;;
              refind)    label="rEFInd" ;;
              *)         label="$vendor" ;;
            esac

            case "$seen_labels" in
              *"|$label|"*) continue ;;
            esac
            seen_labels="$seen_labels|$label|"

             # 1. Strip the root mount path (leaves a leading slash)
            local rel="''${target#"$root"}"

             # 2. Strip the leading slash (prevents the :// bug)
            local limine_rel="''${rel#/}"


            # if_fw_type hides the entry if the machine is ever booted in BIOS
            # mode, where chainloading an EFI binary cannot work.
            printf '//%s\n' "$label"
            printf '    comment: Chainloaded from %s/%s\n' "$volume" "''${limine_rel}"
            printf '    protocol: efi\n'
            printf '    if_fw_type: UEFI\n'
            printf '    path: %s/%s\n' "$volume" "''${limine_rel}"
          done
        }

        # Every *other* EFI System Partition on the machine. NixOS mounts one
        # ESP and no more, so a Windows or a distro installed onto its own
        # disk is invisible until its partition is mounted — which is what
        # this does, read-only and only for as long as the scan takes.
        scan_other_esps() {
          local boot_dev dev parttype partuuid mnt

          # Whatever backs the ESP NixOS boots from; already scanned.
          boot_dev="$(findmnt -no SOURCE --target "$esp" 2>/dev/null || true)"

          # A pipeline would put this loop in a subshell, and $scan_mount has
          # to be visible to the EXIT trap or a failed umount leaks a mount.
          while read -r dev parttype; do
            [ -n "$dev" ] || continue
            [ "$dev" != "$boot_dev" ] || continue

            # The GPT type GUID for an EFI System Partition, and the MBR
            # equivalent for a machine that predates GPT. Anything else is
            # someone's data and has no business being mounted here.
            case "''${parttype,,}" in
              c12a7328-f81f-11d2-ba4b-00a0c93ec93b | 0xef) ;;
              *) continue ;;
            esac

            # limine addresses a volume it did not boot from by filesystem
            # UUID, so one without a readable UUID can't be pointed at even
            # if it does turn out to hold a loader.
            partuuid="$(lsblk -rno PARTUUID "$dev" 2>/dev/null || true)"
            [ -n "$partuuid" ] || continue

            # Mounted already (by hand, or because it is a second NixOS's
            # ESP)? Read it where it is rather than mounting it twice.
            mnt="$(findmnt -nfo TARGET "$dev" 2>/dev/null || true)"
            if [ -n "$mnt" ]; then
              scan_root "$mnt" "guid($partuuid):"
              continue
            fi

            scan_mount="$(mktemp -d)"
            if mount -o ro,nosuid,nodev,noexec "$dev" "$scan_mount" 2>/dev/null; then
              scan_root "$scan_mount" "guid($partuuid):"
              umount "$scan_mount" 2>/dev/null || true
            fi
            rmdir "$scan_mount" 2>/dev/null || true
            scan_mount=""
          done < <(lsblk -rno PATH,PARTTYPE 2>/dev/null || true)
        }

        detect_systems() {
          # boot(): the volume limine itself was loaded from, which is this
          # machine's ESP.
          scan_root "$esp" "boot():"
          ${lib.optionalString cfg.scanAllEsps "scan_other_esps"}
        }

        detect_systems > "$entries" || true

        # Only open the directory entry if something was found — an empty
        # branch in the boot menu is worse than no branch.
        if [ -s "$entries" ]; then
          {
            printf '/+Other operating systems\n'
            cat "$entries"
          } > "$entries.tmp"
          mv -f "$entries.tmp" "$entries"
        fi
      ''}

      # --- rewrite the two regions --------------------------------------
      # A region whose markers aren't in the file is left alone, which is what
      # makes this safe to run against a config generated before this module
      # existed, or by a limine module that has changed shape.
      replace_region() {
        awk -v b="$2" -v e="$3" -v src="$4" -f ${regionAwk} "$1" > "$1.tmp"
        mv -f "$1.tmp" "$1"
      }

      replace_region "$conf" ${lib.escapeShellArg themeBegin} ${lib.escapeShellArg themeEnd} "$body"
      replace_region "$conf" ${lib.escapeShellArg entriesBegin} ${lib.escapeShellArg entriesEnd} "$entries"

      # FAT gives you very little back after an unclean shutdown, and this is
      # the file the machine boots from. The limine installer syncs for the
      # same reason.
      sync -f "$conf" 2>/dev/null || sync
    '';
  };

  defaultTheme = themes.${themeSet.default};
in
{
  # local.* lives in its own module so this one can stay a config attrset.
  # plymouth.nix is the boot splash, off until a host asks for it.
  imports = [
    ./options.nix
    ./plymouth.nix
  ];

  config = lib.mkMerge [
    {
      # Every supported loader here is a UEFI install, and all three want to
      # register themselves with the firmware.
      boot.loader.efi.canTouchEfiVariables = true;
    }

    # --- limine -----------------------------------------------------------
    (lib.mkIf (cfg.loader == "limine") {
      boot.loader.limine = {
        enable = true;

	      maxGenerations = cfg.maxGenerations;
        # Not negotiable while limine-theme-sync exists: enrolling the config
        # hashes it into the bootloader, and the next theme change would then
        # halt the machine at the boot menu. See the header note.
        enrollConfig = false;

        # The build-time state of both regions: the default palette, and no
        # detected systems. The sync replaces the insides of these; the markers
        # themselves come back on every rebuild, from here.
        extraConfig = ''
          ${themeBegin}
          ${themeBlock defaultTheme}
          ${lib.optionalString (cfg.wallpaper != null) wallpaperLines}
          ${themeEnd}
        '';

        extraEntries = ''
          ${entriesBegin}
          ${entriesEnd}
        '';

        # Seeds the image the boot menu falls back to before niri has ever
        # written a wallpaper. Copied to the ESP but outside <esp>/limine, so
        # the installer's cleanup pass leaves it alone — and so the sync can
        # overwrite the same path later.
        additionalFiles = lib.optionalAttrs (cfg.wallpaper != null) {
          "${espSubdir}/wallpaper.png" = cfg.wallpaper;
        };

        # Re-theme immediately after an install rather than at the next boot,
        # so `nixos-rebuild switch` and the boot menu never disagree.
        extraInstallCommands = "${lib.getExe limineSync}";
      };

      systemd.services.limine-theme-sync = {
        description = "Mirror the desktop theme and wallpaper to the limine boot menu";
        wantedBy = [ "multi-user.target" ];

        # The ESP is usually mounted early, but it is not guaranteed to be up
        # before multi-user.target on its own.
        unitConfig.RequiresMountsFor = esp;

        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe limineSync;

          # The other-ESP scan mounts partitions read-only while it reads
          # them. It unmounts them itself, from an EXIT trap — this is the
          # second line of defence: a private mount namespace means even a
          # kill -9 mid-scan can't leave a mount behind on the host.
          #
          # Harmless when scanAllEsps is off; nothing else here mounts
          # anything, and the ESP it writes to is mounted before the
          # namespace is set up (see RequiresMountsFor above).
          PrivateMounts = true;
        };
      };

      systemd.paths.limine-theme-sync = {
        wantedBy = [ "multi-user.target" ];

        # The manifest, and nothing else. `current` used to be watched too,
        # from when it named which prebuilt block to use; it selects nothing
        # now, and Noctalia rewrites the manifest on the same hook, so
        # watching both only meant running the sync twice per theme change.
        # `wallpaper` is not watched because the wallpaper is not mirrored —
        # see the note in the script.
        pathConfig.PathChanged = [ resolvedThemeFile ];
      };
    })

    # --- grub -------------------------------------------------------------
    #
    # The fallback loader. Themed from the palette, but only at build time:
    # grub.cfg is generated by NixOS and has no equivalent of limine's
    # extraConfig/extraEntries regions to rewrite safely, so it does not follow
    # a runtime theme switch the way limine does. It earns its place by finding
    # systems limine can't — os-prober inspects other partitions, rather than
    # only reading this ESP.
    (lib.mkIf (cfg.loader == "grub") {
      boot.loader.grub = {
        enable = true;
        efiSupport = true;
        # EFI install: the boot sector isn't involved, so there is no disk to
        # name here.
        device = "nodev";

        useOSProber = cfg.detectOtherSystems;

        backgroundColor = defaultTheme.bg;
        splashImage = lib.mkIf (cfg.wallpaper != null) cfg.wallpaper;
        splashMode = "stretch";
      };
    })

    # --- systemd-boot -----------------------------------------------------
    #
    # No theming — it has no background or palette to set — and no detection
    # setting, because it already lists Windows and anything else following the
    # Boot Loader Specification without being asked.
    (lib.mkIf (cfg.loader == "systemd-boot") {
      boot.loader.systemd-boot.enable = true;
    })
  ];
}
