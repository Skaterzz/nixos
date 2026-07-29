# fine-ill-try-nix

A NixOS flake for `joshr`'s gaming + development workstation: KDE Plasma 6 on
Wayland, NVIDIA, Steam/ProtonUp-Qt/MangoHud, Docker + Docker Compose,
Flatpak, and a home-manager profile (with
[plasma-manager](https://github.com/nix-community/plasma-manager)) ported
from the [joshrandall8478/dotfiles](https://github.com/joshrandall8478/dotfiles)
chezmoi repo.

## What's here

```
flake.nix                        # inputs: nixpkgs, home-manager, plasma-manager, dotfiles
hosts/gamestation/                # the desk: NVIDIA, multi-monitor
  configuration.nix               # top-level system config, imports the modules below
  hardware-configuration.nix      # PLACEHOLDER — replace with your real hardware scan
hosts/laptop/                     # portable: no NVIDIA, single display
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — regenerate on the machine
modules/nixos/
  base.nix                        # nix settings, locale/timezone, fish, base fonts
  desktop.nix                     # SDDM (Wayland) + Plasma 6, portals, audio, Flatpak
  plasma-xdg-data-dirs.nix        # workaround for nixpkgs#126590 (see below)
  nvidia.nix                      # NVIDIA driver + 32-bit graphics for Steam/Proton
  gaming.nix                      # Steam, MangoHud
  virtualisation.nix               # Docker + Docker Compose
  laptop.nix                       # power-profiles-daemon, upower, thermald, fstrim
  users.nix                        # the `joshr` and `root` accounts
home/common/
  options.nix                      # local.* options the entrypoints toggle
  shell.nix                        # fish + starship, shared by joshr and root
  files/                           # starship.toml, smallfetch.jsonc
home/joshr/
  gamestation.nix                  # host entrypoint: enables the 2nd-monitor panel
  laptop.nix                       # host entrypoint: single-display panels
  home.nix                         # packages (Vivaldi, Spotify, Discord, ProtonUp-Qt, ...)
  kitty.nix                        # kitty terminal + zenwritten_dark theme
  vscode.nix                       # VS Code settings + extension list
  plasma.nix                       # KDE Plasma settings/panels/shortcuts (plasma-manager)
  files/                           # DarkObsidianII.colors
home/root/
  home.nix                         # fish + starship only, no desktop
```

## The root account

`root` uses fish as its login shell and gets the same starship prompt and eza
aliases as `joshr`, via `home/common/shell.nix`. It gets nothing else — no
Plasma, no Kitty config, no GUI packages.

That split isn't invented here; it's what the dotfiles already do. Their
`.chezmoiignore` has a `root` / `jrh` / `jrp` branch that strips the Plasma
configs, Code, spicetify, mpv, vlc, wallpapers, icons and colour schemes, and
`config.fish.tmpl` branches on username to give root an **empty**
`fish_greeting` instead of the fastfetch one. Both behaviours are reproduced
here — the greeting via `local.shell.fastfetchGreeting`, which also decides
whether fastfetch and `~/.smallfetch.jsonc` get installed at all.

Root is managed by home-manager rather than chezmoi, same as joshr. Pointing
chezmoi at the dotfiles repo for root would mean two mechanisms writing to
the same home directories, with chezmoi's state living outside the Nix store
and drifting on its own.

## Where things came from

Your `dotfiles` repo is a chezmoi repo, so it isn't "home-manager-native" —
there's no 1:1 mechanical conversion. What I did instead:

- **Settings** (kdeglobals, plasmarc, kwinrc, kglobalshortcutsrc, the
  appletsrc panel layout, fish config, VS Code settings, kitty config,
  starship.toml) were read from the repo and translated into
  `programs.plasma`/`programs.fish`/`programs.kitty`/`programs.vscode` options
  in `home/joshr/`. Anything that was pure session noise (window-tiling
  geometry caches, per-instance applet UUIDs, dialog-size memory, activity
  UUIDs) was dropped rather than transcribed.
- **Large assets** (fonts, the `Fluent-round-Pursuit` Plasma theme and other
  vendored desktop themes, the two `look-and-feel` packages, the
  `Bibata-Modern-Ice` cursor theme, your custom `j-accent`/`j-contrast` SVGs,
  and your wallpapers) are pulled straight from the `dotfiles` repo via the
  `dotfiles` flake input (see `flake.nix`) instead of being hand-copied. This
  means `nix flake update dotfiles` will pick up changes you push to that repo.
- **VS Code extensions** aren't declaratively pinned (most aren't packaged in
  nixpkgs), so `vscode.nix` reinstalls them from the marketplace on every
  `home-manager switch`, mirroring what `scripts/install-vscode-extensions.sh`
  did in the original repo.
- Things I could find no evidence you'd actually customized (e.g. almost all
  of `kglobalshortcutsrc`, which was stock KDE defaults) were left alone
  rather than guessed at.
- **Per-machine profiles have no direct equivalent here.** The dotfiles repo
  uses chezmoi templates (`.chezmoiignore`, `config.fish.tmpl`) to branch on
  OS, username, and hostname — notably a shell-and-starship-only profile for
  root and for `jrh`/`jrp` hostnames. In Nix that job belongs to separate
  `nixosConfigurations.<host>` entries in `flake.nix` rather than to
  in-file conditionals, so nothing was ported for it. If you want a minimal
  laptop host that skips Plasma/gaming, that's a new host entry importing a
  subset of `modules/nixos/`.

## Before you build this

1. **Hardware config.** `hosts/gamestation/hardware-configuration.nix` is a
   placeholder — it has invented disk labels and a guessed CPU vendor, and
   will not boot your machine. See
   [Regenerating hardware-configuration.nix](#regenerating-hardware-configurationnix)
   below.
2. **NVIDIA generation.** `modules/nixos/nvidia.nix` defaults to the
   proprietary kernel module (`open = false`). If your card is a Turing
   (RTX 20xx) or newer, you can flip that to `true` to use the open kernel
   module instead.
3. **Multi-monitor panel layout.** `home/joshr/plasma.nix` assumes the same
   monitor arrangement as the original machine: a dock and a status bar on
   `screen = 0`, and one bar on `screen = 1`. (Screen 2 has a desktop but no
   panel, matching the upstream dotfiles.) If this is a different machine,
   adjust or drop the `screen` numbers.
4. **Git identity.** `home/joshr/home.nix` sets
   `programs.git.userEmail = "joshrandall8478@gmail.com"` — change it if
   that's not the identity you want for commits.

## Regenerating hardware-configuration.nix

`nixos-generate-config` scans the running machine — disks, filesystem UUIDs,
kernel modules needed at boot, CPU vendor — and writes a Nix module
describing it. It is machine-specific and must be regenerated per host.

**On a machine that already runs NixOS:**

```bash
sudo nixos-generate-config --show-hardware-config \
  > hosts/gamestation/hardware-configuration.nix
```

`--show-hardware-config` prints to stdout instead of writing into
`/etc/nixos`, which is what you want when the file lives in a repo.

**During a fresh install**, it's generated as part of the install flow below
(step 4), after the target disk is mounted at `/mnt`.

Either way, open the result and sanity-check it — in particular
`boot.initrd.availableKernelModules` (needs your storage controller) and that
`fileSystems` entries point at the right devices.

## Fresh install from the NixOS ISO

Boot the NixOS installer ISO (the minimal or graphical image, either works)
and get a network connection.

**1. Partition and format.** This config uses `systemd-boot`, so the disk
must be GPT with an EFI system partition. Replace `/dev/nvme0n1` with your
actual disk (`lsblk` to find it) — **this erases it**:

```bash
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 1GB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart root ext4 1GB 100%

sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2
```

**2. Mount.**

```bash
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

**3. Clone this repo to where it will live permanently.** Putting it at
`/mnt/etc/nixos` means it survives the reboot and is where you'll edit it
later:

```bash
sudo nix-shell -p git --run \
  'git clone https://github.com/joshrandall8478/fine-ill-try-nix /mnt/etc/nixos'
```

**4. Generate the hardware config into the repo.**

```bash
sudo nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/etc/nixos/hosts/gamestation/hardware-configuration.nix
```

**5. Commit it — this step is not optional.** Flakes only see files that git
tracks. A newly written, untracked `hardware-configuration.nix` is invisible
to the evaluator and the install will fail with a confusing "path does not
exist" error:

```bash
cd /mnt/etc/nixos
sudo nix-shell -p git --run 'git add hosts/gamestation/hardware-configuration.nix'
```

(You don't have to `git commit` — staging is enough for the flake to see it —
but committing keeps things tidy.)

**6. Install.** This builds the whole system, so expect it to take a while
and pull down a lot (NVIDIA driver, Plasma, Steam, VS Code):

```bash
sudo nixos-install --flake /mnt/etc/nixos#gamestation
```

If the installer's Nix complains about experimental features, prefix it:

```bash
sudo NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-install --flake /mnt/etc/nixos#gamestation
```

`nixos-install` prompts for a **root** password at the end.

**7. Reboot and log in.** `joshr`'s initial password is `changeme` (set in
`modules/nixos/users.nix`). Change it immediately:

```bash
passwd
```

That new password persists — `initialPassword` only applies at account
creation, and editing it later does nothing.

**8. Commit `flake.lock`.** The first build generates one, pinning every
input to an exact revision. Commit it:

```bash
cd /etc/nixos
sudo git add flake.lock && sudo git commit -m "Pin flake inputs"
```

This matters more than it looks. `flake.nix` tracks `nixos-unstable`, so
**without a committed lock file every build resolves to whatever nixpkgs
HEAD happens to be that day** — meaning a rebuild that worked yesterday can
fail today because a package got renamed upstream. With the lock committed,
inputs only move when you explicitly run `nix flake update`.

## The XDG_DATA_DIRS workaround (nixpkgs#126590)

`modules/nixos/plasma-xdg-data-dirs.nix` works around a long-standing NixOS
bug where Plasma's Qt wrapper builds an `XDG_DATA_DIRS` of roughly 18 KB with
heavy duplication. Every process in the session inherits it, and since
applications stat every entry on startup looking for `.desktop` files, icons
and mime data, the whole session feels slow to launch things. It's especially
bad on storage with high per-operation latency — a VM disk, for instance.

The module merges all those `share/` directories into one derivation and
points the wrapper at that instead, taking `XDG_DATA_DIRS` down to two
entries. Taken from
[this comment](https://github.com/NixOS/nixpkgs/issues/126590#issuecomment-3194531220).

**It rebuilds `plasma-workspace` from source.** A modified derivation gets no
binary cache hit, so this recompiles on every `nix flake update` that touches
the package — think tens of minutes, more in a VM. If that trade stops being
worth it, drop the import from `hosts/gamestation/configuration.nix`; nothing
else depends on it.

## Rebuilding after changes

Once installed, from the repo (`/etc/nixos` if you followed the above):

```bash
sudo nixos-rebuild switch --flake .#gamestation
```

Useful variants:

```bash
# Build and check it evaluates, without activating:
sudo nixos-rebuild build --flake .#gamestation

# Activate now but don't add a boot entry (reverts on reboot — good for
# testing risky NVIDIA/kernel changes):
sudo nixos-rebuild test --flake .#gamestation

# Update all flake inputs (nixpkgs, home-manager, plasma-manager, dotfiles):
nix flake update

# Update just one input (e.g. after pushing to the dotfiles repo):
nix flake update dotfiles
```

`nix flake update` rewrites `flake.lock` — commit it alongside whatever
prompted the update, so a build that works is a build you can get back to.
If an update breaks something, `git checkout flake.lock` and rebuild.

If a rebuild leaves you with a broken desktop, pick the previous generation
from the systemd-boot menu at startup — nothing is destroyed by a bad switch.

## Hosts

Two are defined. Pick one with the flake attribute:

| Host | For | Differences |
|---|---|---|
| `gamestation` | the desk | NVIDIA module; second-monitor panel |
| `laptop` | portable | no NVIDIA; power management; single-display panels |

```bash
sudo nixos-rebuild switch --flake .#gamestation
sudo nixos-rebuild switch --flake .#laptop
```

Both share everything else — the same modules, the same `home/joshr` profile,
the same Plasma theming, the same package set.

### What actually differs

**Panels.** `home/joshr/plasma.nix` is shared. The second-monitor status bar
is gated behind `local.plasma.secondaryMonitorPanel`, which
`home/joshr/gamestation.nix` turns on and `home/joshr/laptop.nix` leaves off.
The dock and the primary status bar are on `screen = 0` and appear on both.
If the laptop gets docked to external displays and you want that bar back,
set the option to `true` in `home/joshr/laptop.nix`.

**Graphics.** `laptop` deliberately does *not* import `modules/nixos/nvidia.nix`
— that module hard-sets `services.xserver.videoDrivers = [ "nvidia" ]` for a
single always-on discrete GPU, which is wrong for integrated-only machines and
wrong for Optimus hybrids. If the laptop does have an NVIDIA chip, read the
comment at the bottom of `hosts/laptop/configuration.nix`: hybrids want PRIME
offload, not that module as written.

**Power.** `modules/nixos/laptop.nix` adds power-profiles-daemon (which backs
Plasma's power-profile switcher and the `Meta+B` shortcut from the dotfiles),
upower, thermald and fstrim.

Each host still needs its own hardware scan —
`hosts/laptop/hardware-configuration.nix` is the same placeholder as
gamestation's and must be regenerated on the machine.

### Adding a third host

1. `mkdir -p hosts/<newhost>`, write a `configuration.nix` importing the
   modules that apply, and generate its `hardware-configuration.nix`.
2. Add a `<newhost> = mkHost { ... }` entry to `nixosConfigurations` in
   `flake.nix`, pointing at that host module and a home entrypoint.
3. Install with `--flake /mnt/etc/nixos#<newhost>`.

## I couldn't fully validate this here

This was written in a sandboxed environment without network access to
nixos.org/the Nix binary cache, so **`nix flake check` has not been run**.
Everything was hand-reviewed against the actual plasma-manager and
home-manager module sources (fetched via `raw.githubusercontent.com`) rather
than from memory, but please run `nix flake check` before your first
`nixos-rebuild switch`, and expect to iterate on:

- `hardware-configuration.nix` (definitely needs regenerating, see above)
- exact widget/option names in `plasma.nix` if plasma-manager's schema has
  moved since this was written
- the NVIDIA `open` kernel module flag for your specific GPU

## Updating the dotfiles-derived assets

```bash
nix flake update dotfiles   # pull in changes from joshrandall8478/dotfiles
```
