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
hosts/gamestation/
  configuration.nix               # top-level system config, imports the modules below
  hardware-configuration.nix      # PLACEHOLDER — replace with your real hardware scan
modules/nixos/
  base.nix                        # nix settings, locale/timezone, fish, base fonts
  desktop.nix                     # SDDM (Wayland) + Plasma 6, portals, audio, Flatpak
  nvidia.nix                      # NVIDIA driver + 32-bit graphics for Steam/Proton
  gaming.nix                      # Steam, MangoHud
  virtualisation.nix               # Docker + Docker Compose
  users.nix                        # the `joshr` user account
home/joshr/
  home.nix                         # packages (Vivaldi, Spotify, Discord, ProtonUp-Qt, ...)
  fish.nix                         # fish shell, eza aliases, starship, fastfetch greeting
  kitty.nix                        # kitty terminal + zenwritten_dark theme
  vscode.nix                       # VS Code settings + extension list
  plasma.nix                       # KDE Plasma settings/panels/shortcuts (plasma-manager)
  files/                           # small config files copied in verbatim (starship.toml, etc.)
```

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
   placeholder. On the real machine:
   ```bash
   sudo nixos-generate-config --show-hardware-config > hosts/gamestation/hardware-configuration.nix
   ```
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

## Building

```bash
git clone <this repo> && cd fine-ill-try-nix
# after generating hardware-configuration.nix as above:
sudo nixos-rebuild switch --flake .#gamestation
```

For just the home-manager profile on a non-NixOS or already-installed system:

```bash
nix run home-manager -- switch --flake .#joshr
```

(You'd need to add a standalone `homeConfigurations.joshr` output for that —
right now home-manager is wired in as a NixOS module only, applied together
with the system config.)

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
