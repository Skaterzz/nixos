# nixos-config

A NixOS flake for `joshr`'s gaming + development workstation: KDE Plasma 6 on
Wayland, NVIDIA, Steam/ProtonUp-Qt/MangoHud, Docker + Docker Compose,
Flatpak, and a home-manager profile (with
[plasma-manager](https://github.com/nix-community/plasma-manager)) ported
from the [joshrandall8478/dotfiles](https://github.com/joshrandall8478/dotfiles)
chezmoi repo.

## What's here

```
flake.nix                        # inputs: nixpkgs, home-manager, plasma-manager,
                                 #   dotfiles, wallhaven-toplist
hosts/gamestation/                # the desk: NVIDIA, multi-monitor
  configuration.nix               # top-level system config, imports the modules below
  hardware-configuration.nix      # PLACEHOLDER — replace with your real hardware scan
  kernel-params.nix               # boot.kernelParams, shared with gamestation-niri
hosts/laptop/                     # portable: no NVIDIA, single display
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — regenerate on the machine
hosts/server/                     # headless: no desktop, cron jobs
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — regenerate on the machine
modules/nixos/
  base.nix                        # nix settings, locale/timezone, fish, base fonts
  plasmalogin.nix                     # SDDM (Wayland) + Plasma 6, portals, audio, Flatpak
  development.nix                 # direnv, Docker, nix settings — commented out
                                  #   per host, see below
  virtualization.nix              # libvirtd/QEMU/virt-manager — imported per host
  default-apps.nix                # /etc/xdg/mimeapps.list — file associations,
                                  #   overridable from a settings panel
  cron.nix                        # local.cron.jobs -> the system crontab
  emoji.nix                       # Microsoft Fluent Emoji as the system emoji font
  plasma-xdg-data-dirs.nix        # workaround for nixpkgs#126590 (see below)
  nvidia.nix                      # NVIDIA driver + 32-bit graphics for Steam/Proton
  gaming.nix                      # Steam, MangoHud
  laptop.nix                       # power-profiles-daemon, upower, thermald, fstrim
  power.nix                        # no idle suspend while on mains power
  boot.nix                         # bootloader: limine theming + other-OS detection
  options.nix                      # local.boot.*, local.power.*, local.sddm.*
  users.nix                        # the `joshr` and `root` accounts
home/common/
  options.nix                      # local.* options the entrypoints toggle
  shell.nix                        # fish + starship, shared by joshr and root
  files/                           # starship.toml, smallfetch.jsonc
home/joshr/
  gamestation.nix                  # host entrypoint: enables the 2nd-monitor panel
  laptop.nix                       # host entrypoint: single-display panels
  server.nix                       # host entrypoint: shell only, no desktop base
  home.nix                         # packages (Spotify, Discord, ProtonUp-Qt, ...)
  browser.nix                      # the default browser: Vivaldi, $BROWSER
                                   #   (handlers: modules/nixos/default-apps.nix)
  firefox.nix                      # Firefox: profile, prefs, sync (installed, not default)
  wallhaven.nix                    # wallhaven's top 20 -> ~/.local/share/wallpapers/
                                   #   WallhavenFlake, from the locked listing
  kitty.nix                        # kitty terminal + zenwritten_dark theme
  vscode.nix                       # VS Code settings + extension list
  niri/                            # the niri desktop; see the section below
    default.nix                    #   imports, GTK/Qt theming, Dolphin
    themes.nix theming.nix         #   the palettes, and every generated config
    niri.nix waybar.nix            #   compositor config and the bar
    scripts.nix notifications.nix  #   theme/wallpaper/lock/screenshot helpers
    clipboard.nix                  #   clipboard history
    emoji.nix                      #   the Mod+. emoji picker
    vscode.nix lock.nix            #   editor theming, idle handling
  plasma.nix                       # KDE Plasma settings/panels/shortcuts (plasma-manager)
  files/                           # DarkObsidianII.colors
home/root/
  home.nix                         # fish + starship only, no desktop
templates/                         # `nix flake init -t` dev environments
  generic/ python/ node/ rust/ go/
```

## niri (experimental alternative to Plasma)

There are niri variants of both machines. They're separate hosts rather than
a switch inside the existing ones, because Plasma here uses
plasma-login-manager and niri uses SDDM — NixOS won't enable two display
managers at once.

```bash
sudo nixos-rebuild switch --flake .#gamestation-niri   # try niri
sudo nixos-rebuild switch --flake .#gamestation        # back to Plasma
```

Nothing is destroyed either way, and the previous generation stays in the
boot menu. `laptop-niri` is the same deal for the laptop.

The niri hosts deliberately **don't** import `plasma-xdg-data-dirs.nix`.
That workaround exists because plasma-workspace's Qt wrapper builds an ~18 KB
`XDG_DATA_DIRS`; there's no plasma-workspace in a niri session, so the bug
can't occur — and neither can the from-source rebuild the workaround costs.

### Layout

```
modules/nixos/niri.nix        # session, SDDM + theme, polkit, PAM, portals
modules/nixos/ddcci.nix       # DDC/CI brightness for external monitors
home/joshr/displays/
  gamestation.nix             # DP-3 + DP-2 layout — edit here for monitors
  laptop.nix                  # empty: niri auto-detects
home/joshr/niri/
  default.nix                 # entrypoint: packages, GTK/Qt/cursor
  themes.nix                  # the palettes — edit colours here
  theming.nix                 # renders each palette into per-tool configs
  niri.nix                    # config.kdl: binds, layout, window rules
  waybar.nix                  # bar layout + style
  notifications.nix           # dunst + wofi
  osd.nix                     # swayosd: the volume/brightness pop-up
  lock.nix                    # swayidle timers
  scripts.nix                 # theme/wallpaper/screenshot/session helpers
```

### The bar

Left is the username, workspaces and the focused window title, centre is the
clock and date, right is the tray, media controls, volume, network, battery,
the idle inhibitor, then **lock** and **power** as a matched pair at the far
end. Each group is its own rounded floating pill rather than one long bar.

**The username** is the first slot, in the accent colour — the same treatment
the clock gets, because both are labels rather than controls. It's static
text with no `exec`: the name comes from `config.home.username` at build
time, so there's no subprocess polling for a string that can't change while
the bar is running, and a second user's generation renders their own name
without editing anything.

Lock and power are styled identically and differ only on hover — the power
button goes red, because it's the one that can end the session. The lock
button runs the same `lock-session` as `Mod+L` and the session menu's "Lock"
entry, so all three take the active theme's colours.

**The visualiser** is eight bars of cava just left of the track name, in the
theme's dimmed accent. It is only there while something is actually making
noise: the script prints an empty line on a silent frame and waybar hides a
custom module with no text, so the bar looks exactly as it did before
whenever nothing is playing — no reserved slot, no flat row of glyphs.

It follows the *audio*, not the mpris player, so a notification chime blips
it for a moment too. That's the trade for needing no polling and no second
process: cava already knows whether there's sound. Tying it to the player
would mean gating the loop on `playerctl --follow status`.

After two seconds of silence cava stops doing FFT and only checks for input
once a second, so the idle cost is close to nothing. `cava` is also on PATH
on its own — running it in a terminal is the quickest way to tell whether
it's cava or the widget at fault if the bar stays empty. See `cavaBar` in
`home/joshr/niri/scripts.nix`.

### The on-screen display

Volume and brightness raise a pop-up — icon, bar and the number, low and
centred on every output, in the active theme's colours. niri has none of its
own, being a compositor and nothing else, so before this the keys were silent:
the level moved and the only way to see where it had landed was waybar, which
shows volume but not brightness, and only on the display you happen to be
looking at.

**swayosd** draws it. `swayosd-server` is a user service (`osd.nix`); a
one-shot `swayosd-client` asks it to draw over the session bus. The mute keys
get a worded message instead of a bar — "Muted", "Microphone muted" — because a
toggle has no level to show, and because a client request can't grey out the
bar the way swayosd's own volume OSD does.

**swayosd never changes anything, only draws.** `swayosd-client --output-volume
raise` would do both in one call, and that is the usage its README documents,
but with the server down it does neither — a crashed OSD daemon would take the
media keys with it. So `volume` and `brightness` (`scripts.nix`) make the
change themselves, read the result back, and then ask for a pop-up, with every
one of those calls best-effort. The worst case is a change you don't see.

Brightness has a second reason: swayosd drives `brightnessctl` with at most one
`--device`, which is the exact thing `brightness` exists to work around (see
"Brightness" below), and asking it for a wildcard makes `brightnessctl get`
print one line per display into a parser that wants a single number.

Reading the level back rather than predicting it is also what keeps the number
honest — clamping at 0% and 100% is `brightnessctl`'s and `wpctl`'s, and a
level computed here would be wrong at both ends of the range. `volume show`
draws the current level without changing it, which is the quickest way to tell
whether the daemon is up.

Every route to the volume goes through that one script: the media keys, and
waybar's click-to-mute and scroll. The bar's scroll passes an explicit step of
1, since a scroll notch moves a single point where a key moves five —
`scroll-step` no longer does anything once `on-scroll-up`/`on-scroll-down` are
set, so it's gone from the module rather than left there looking load-bearing.

It appears on **every** output rather than only the focused one, which is
swayosd's default and is left alone. `swayosd-client --monitor <name>` would
narrow it, but only if something works out which output is focused first —
`niri msg focused-output` on every keypress, with a fallback for when that
fails — and two small pop-ups is a cheaper thing to live with than a key that
sometimes shows nothing.

Two things it deliberately doesn't do. **The idle dim doesn't raise one**: the
dim happens when you've stopped touching the machine and the restore happens
the instant you touch it again, so a pop-up on the way back would fire on every
return to the desk to report a level that hasn't changed. And **nothing shows
on the lock screen** — a session lock draws above every layer-shell surface,
which is the point of it. The keys still work there; `allow-when-locked` is
about the volume moving, not about the pop-up.

The libinput backend — caps lock, num lock, scroll lock — is not set up. That
half is a system service wanting udev rules and polkit, it reads every input
device to do its job, and none of the three keys is one this session has
anything to say about.

### Theme switching

20 palettes ship. Greens: `matrix` (bright phosphor, the default), `forest`,
`mint`. Monochrome: `mono` (white on black), `mono-light` (black on white).
Reds: `blackred`, `crimson`. Then `catppuccin-mocha`,
`catppuccin-macchiato`, `catppuccin-frappe`, `rose-pine`, `rose-pine-moon`,
`nord`, `gruvbox`, `dracula`, `tokyo-night`, `everforest`, `kanagawa`,
`solarized`, and `rose-pine-dawn` as the one light option.

`Mod+Shift+T` jumps to a random one, `Mod+Ctrl+T` opens a picker (more useful
at this count). That matches the wallpaper keys — `Mod+Shift` is the random
half of both pairs, `Mod+Ctrl` the deliberate half. The theme currently active
is excluded from the draw, so the key always visibly does something; at 20
palettes a plain random pick would land on the current one about one press in
twenty, and a keybind that occasionally appears to do nothing reads as broken
rather than as chance. `theme-cycle` is still on PATH if you want the ordered
walk.

The mechanism is worth knowing, because it's what keeps this declarative.
home-manager owns `~/.config/...` as read-only symlinks into the store, so a
script can't rewrite them. Instead every theme is **built ahead of time** as a
complete set of config files, and the only mutable state is one symlink:

```
~/.local/state/niri-theme/active -> /nix/store/...-niri-theme-matrix
```

Each tool is pointed at a file under that symlink: niri via its `include` node
(live-reloaded), waybar started with `-s <active>/waybar.css`, wofi via its
`style` config key, dunst via `services.dunst.configFile`, swayosd via
`--style <active>/swayosd.css`, kitty via an `include` at the end of
`kitty.conf`. `theme-apply` moves the symlink, restarts waybar, dunst and
swayosd, and sends kitty SIGUSR1 so open terminals repaint in place; wofi
re-reads on each launch.

**Dolphin and other KDE apps** read `~/.config/kdeglobals`, which is a symlink
into the active theme. Two things have to be true for that to work, and the
second is easy to get wrong: `qt.platformTheme.name` must be `"kde"`, not
`"gtk"`. The GTK platform plugin reads colours out of the *GTK* theme and
never opens `kdeglobals` at all, so with it loaded Dolphin comes out in
Adwaita grey whatever palette is selected. With the KDE plugin in place,
`theme-apply` also emits KDE's palette-changed signal on the session bus —
the same one Plasma sends when you apply a colour scheme — so an open Dolphin
repaints without being restarted. That part is best effort; anything that
doesn't listen picks the change up next time it starts.

That `"kde"` costs one thing worth knowing about. home-manager maps the name
to a fixed package list, and it includes **KDE System Settings** — which is
why that app used to appear in the launcher on a session with no Plasma to
configure. `qt.platformTheme.package` is therefore spelled out in
`home/joshr/niri/default.nix`: the module takes the first non-empty of
[your list, the name's list], so naming `kio` and `plasma-integration`
explicitly means the third one is never installed. Both of those are
load-bearing — the KDE file dialog and the plugin that reads `kdeglobals` —
and `QT_QPA_PLATFORMTHEME` is still `kde`. The Plasma hosts are unaffected;
they get System Settings from Plasma itself.

**VS Code** has no "read colours from this path" setting — a colour theme can
only arrive as an extension. So each palette renders a complete one-theme
extension, and `home/joshr/niri/vscode.nix` symlinks the whole directory into
`~/.vscode/extensions`. `workbench.colorTheme` is therefore pinned to `"Niri"`
forever: a switch re-points the symlink at a different build of the same
extension, and the name in `settings.json` — which lives in the store and
can't change at runtime — never has to. Restart the editor to see it.

**Firefox** is the same shape as Dolphin: its profile's `chrome/userChrome.css`
and `userContent.css` are symlinks into the active theme, read once at
startup. See "The browser" below.

Adding a theme is one attrset in `themes.nix` — the niri fragment, both
stylesheets, the dunstrc, the OSD's stylesheet, the swaylock palette, the SDDM
config, Dolphin's kdeglobals, VS Code's extension and Firefox's two chrome
stylesheets are all generated from its ten colour roles.

The OSD's sheet is the one that overrides rather than replaces: swayosd loads
its own at GTK's APPLICATION priority and ours at USER priority, which is
higher, so only the colours and the corner radius are restated and the layout
stays upstream's. It is written against GTK4 node names — `window#osd`,
`#container`, `progressbar > trough > progress` — because swayosd 0.3 is a
GTK4 application, and it spells its `rgba()` channels out rather than using
GTK's `alpha(@theme_bg_color, …)`, which resolves only if the loaded GTK theme
defines that name.

kitty is the exception, because a terminal needs sixteen ANSI colours and ten
semantic roles don't contain them — there's no blue, magenta or cyan in a
palette built for a bar and a focus ring. So each theme also carries an `ansi`
block. Themes with a published terminal palette (Catppuccin, Nord, Gruvbox,
Dracula, Tokyo Night, Rosé Pine, Everforest, Kanagawa, Solarized) use it
verbatim, quirks included — Rosé Pine maps "green" to a teal, Solarized's
bright slots are greys rather than brighter hues. The rest are hand-picked.
Omitting `ansi` is allowed and falls back to a derivation from the ten roles,
but it's flat: blue, magenta and cyan all collapse onto the accent.

One trap worth knowing if you ever edit the greeter's clock: SDDM reads a
theme's config through `QSettings(path, QSettings::IniFormat)`, and QSettings'
INI format treats an **unquoted comma as a list separator**. So a `DateFormat`
of `dddd, MMMM d` comes back as the two-element list `["dddd", "MMMM d"]`,
which `Clock.qml` then hands to `Date.toLocaleDateString(locale, format)` —
a function that takes a string or a format enum and nothing else. The month
silently disappears. The format here uses a middle dot instead of a comma for
that reason; quoting the value also works, but only because the reader happens
to be QSettings.

The login screen does **not** follow, by default. It uses SDDM's built-in
greeter, because the themed one left the primary display black — see "The
login screen" below. `local.sddm.theme = "astronaut"` turns the themed
version back on, which builds one `sddm-astronaut` instance per palette and
has a system path unit rewrite an SDDM drop-in when the selection changes.
SDDM only reads its config when the greeter starts, so that lands at the next
logout or reboot rather than immediately.

Wallpapers use `awww` (the renamed `swww`) over `~/.local/share/wallpapers`:
`Mod+Shift+W` is random, `Mod+Ctrl+W` picks one. The choice is remembered and
restored at login.

**Whose theme the machine follows** is `local.desktop.primaryUser`, which
defaults to `joshr`. Three things live outside any session and have to be
dressed from *someone's* choices: the SDDM greeter and the limine boot menu
both read the theme and wallpaper out of that user's
`~/.local/state/niri-theme`, and plasmalogin copies Plasma's settings out of
their `~/.config`.

Each of those is a singleton — one login screen, one boot menu — so this
can't be generalised to "whoever is logged in" without the last person to
pick a theme deciding what the machine looks like at boot. Naming one owner
is the honest version. Pointing it at an account that never opens a niri
session isn't an error either: the sync services find no state file and leave
the greeter and boot menu on the default palette.

### Keys

| Key | Action |
|---|---|
| `Mod+Return` / `Mod+D` / `Mod+E` / `Mod+B` | terminal, launcher, Dolphin, browser |
| `Mod+Ctrl+E` | ranger, in a terminal |
| `Mod+Ctrl+V` | clipboard history |
| `Mod+.` | emoji picker |
| `Mod+Q` / `Mod+O` | close window, overview |
| `Mod+H/J/K` | focus (arrows also work; `Mod+L` is lock, so use `Mod+Right`) |
| `Mod+1..5` | named workspaces |
| `Mod+R` / `Mod+F` / `Mod+V` | preset widths, maximize, float |
| `Mod+W` | tab the focused column — its windows stack, one shown at a time |
| `Print` / `Mod+Shift+S` | region screenshot, annotated in satty |
| `Shift+Print` / `Mod+Ctrl+S` | same region as last time, no selection step |
| `Ctrl+Print` / `Alt+Print` | screen / window (niri's built-ins) |
| `Mod+L` / `Mod+Shift+Escape` | lock, session menu |
| `Mod+Escape` | blank the monitors — works on the lock screen too |
| `Mod+Shift+I` | stay awake (toggle the sleep inhibitor) |
| `Mod+Shift+T` / `Mod+Ctrl+T` | random theme, pick theme |
| `Mod+Shift+W` / `Mod+Ctrl+W` | random wallpaper, pick wallpaper |
| volume / brightness keys | change it and show an OSD — see "The on-screen display" |
| `Mod`+scroll / `Mod+Shift`+scroll | walk windows / workspaces (wheel and touchpad) |

`Mod+W` is the one that isn't guessable from the key. A column normally
divides its height between the windows stacked in it, so a column of four is
four short windows. Tabbed, they share one full-height slot and only the
focused one is drawn, with an indicator marking the rest — the column still
takes one slot on the strip, and `Mod+K`/`Mod+J` walk the tabs. `Mod+W` again
puts the stack back. Nothing moves in or out of the column either way; it's
purely how the column is drawn.

`Mod+Shift+Slash` shows niri's own **Important Hotkeys** overlay. That's a
shorter list than the table above: niri hardcodes the entries it considers
important, and anything else appears only if its bind carries a
`hotkey-overlay-title`. `Mod+W` is given one for exactly that reason — the
titled binds land after the hardcoded ones. Scroll binds can't appear there
at all, so `Mod`+scroll stays a table-only entry.

### Clipboard history

`Mod+Ctrl+V` opens the history in wofi; picking an entry puts it back on the
clipboard. `clipboard-wipe` empties it, and isn't bound to a key on purpose.

**Removing single entries**, two ways, because wofi has no way to put a button
on a row:

- **`Delete`** in the picker removes the entry under the cursor and reopens
  it, so several can go in a row.
- **`✕  Delete entries…`**, the first row of the list, switches the picker
  into a mode where Enter — or a mouse click — removes instead of copies.
  `←  Back to copying` returns. This is the discoverable version, and the
  only one reachable with a mouse.

`Backspace` is deliberately not bound. wofi's dmenu mode puts the cursor in a
search box and Backspace is how you correct what you typed there, so binding
it would make the history impossible to search. `Delete` is free, which is
why it's the one. Adding another (`Shift-BackSpace`, say) is one more
`--define=key_custom_1=…` in `clipboard.nix` plus its exit code in the case
at the bottom of the loop.

The bind is passed with wofi's `--define`, not set in `programs.wofi.settings`
— that config is shared with the launcher and the theme, wallpaper and session
menus, and binding `Delete` globally would arm a delete exit code in all of
them. One caveat from wofi(5): a custom key *"will not cause wofi to exit, it
will only set its exit code for when it does"*, so on wofi 1.5.3 `Delete` takes
effect when the picker is next dismissed. Either way it's the entry under the
cursor that goes, and the script handles both behaviours.

Wayland has no clipboard manager in the compositor — a copied selection lives
in the process that copied it and vanishes when that process exits, which is
why closing a browser tab loses what you just copied out of it. `cliphist`
plugs that hole: home-manager runs it as two `wl-paste --watch` user services,
one for text and one for images, and it keeps the last 300 entries.

Images are stored too. They show in the picker as `[[ binary data … ]]`;
choosing one puts the real image back on the clipboard, so pasting into an
image-aware app still works.

`Mod+V` and `Mod+Shift+V` were already float and float/tile focus, hence the
third spelling.

See `home/joshr/niri/clipboard.nix`.

### Emoji picker

`Mod+.`, because that's the key Windows uses and that reflex is the whole
reason it exists. Type to search by name, `Enter` to pick, `Escape` to
cancel — and what you use most floats to the top of the list next time.

The emoji is **typed into the focused window and put on the clipboard**, both.
Typing alone would be the closer copy of Windows, but it depends on the window
accepting synthetic keystrokes, and when one doesn't there'd be nothing to
show for the keypress. The clipboard is the fallback that's already in place
by the time typing is attempted. `cliphist` keeps whatever selection it
displaced, so nothing is lost either way.

It's [`bemoji`](https://github.com/marty-oehme/bemoji) driving wofi, with two
things changed:

- **The list is built at build time**, not downloaded. bemoji normally curls
  `unicode.org/Public/emoji/latest/emoji-test.txt` into `~/.local/share/bemoji`
  on first run. That puts a keybind behind the network, behind a `latest` URL
  that moves, and behind mutable state no rebuild reproduces — so the same
  transformation runs in a derivation instead, against the pinned copy in
  `pkgs.unicode-emoji`, and `BEMOJI_DB_LOCATION` points at the store path.
  Pointing it there also settles the download question permanently: bemoji only
  fetches when that directory comes back empty, and a store path never is. The
  derivation fails the build if the parse yields fewer than a thousand entries,
  so a format change upstream stops the rebuild rather than shipping an empty
  picker.
- **Typing goes through a wrapper** that sleeps 150 ms first. `wtype` starts
  the moment wofi exits, and niri needs a beat to hand focus back to the
  window underneath; without the pause the keystrokes can land while nothing
  is focused yet.

Only the picker's own history at `~/.local/state/bemoji` is mutable. Adding
another list — symbols, kaomoji — means adding a file to the derivation in
`emoji.nix`, not dropping one in a directory.

`Mod+.` used to be `expel-window-from-column`, which moved to
`Mod+Shift+Period`. `Mod+BracketLeft` / `Mod+BracketRight` already consume and
expel, and they're the pair that reads as a direction, so nothing is really
lost.

The picker gets its own stylesheet, `wofi-emoji.css`, generated from the same
palette as `wofi.css` with rows at 20px — big enough to tell 😀 from 😃 at a
glance, with the search box left at the normal size. It follows theme
switches like everything else.

**The font is Microsoft's Fluent Emoji**, which is what makes this look like
the thing `Win+.` opens rather than like Android. nixpkgs has no Fluent Emoji
font — Microsoft publishes `fluentui-emoji` as loose SVG and PNG assets and
the packaging request ([nixpkgs#347889](https://github.com/NixOS/nixpkgs/issues/347889))
was closed as not planned — so `modules/nixos/emoji.nix` packages
[tetunori/fluent-emoji-webfont](https://github.com/tetunori/fluent-emoji-webfont),
a build of those assets into a real font, pinned to its v0.8.5 commit. It's
set as `fonts.fontconfig.defaultFonts.emoji`, so it's what Firefox, kitty,
Discord and everything else draw too, with `noto-fonts-color-emoji` left
behind it to cover anything Unicode has added since the Fluent set was last
built.

It is an 87 MB font, which is most of what this costs. The build carries three
colour formats for the same 33k glyphs — CBDT bitmaps, COLRv1 vectors and
OT-SVG — because it's meant for browsers, where which one gets used depends on
the engine. FreeType needs one of them. It ships whole anyway: stripping tables
means a fonttools pass whose output would have to be trusted sight-unseen, and
a silently broken emoji font is worse than a large one.

See `home/joshr/niri/emoji.nix` and `modules/nixos/emoji.nix`.

On the Plasma hosts the font applies just the same, and `Meta+.` is already
KDE's own emoji picker (`plasma-emojier`). That default is restated explicitly
in `home/joshr/plasma.nix` — the one place that file states a stock KDE
default on purpose — so the same key can't quietly mean different things
depending on which session booted.

### Staying awake

`Mod+Shift+I`, or the coffee-cup icon in the bar, holds the machine awake.
The icon is dim when idling is normal and lit when the inhibitor is on — it's
a mode that's easy to leave running by accident, so it's meant to be obvious.
Clicking and keying run the same script, and the state lives in
`idle-inhibit.service`, so the two can't disagree.

It holds off two unrelated mechanisms, which is why it isn't a one-liner:

- **swayidle** dims, locks and blanks. It takes its cue from the compositor's
  idle-notify protocol, not from logind, so a logind inhibitor does nothing to
  it — the timer is stopped outright and restarted on the way back.
- **logind** handles the idle action, sleep, and the lid switch.
  `systemd-inhibit` holds a block lock on all three for as long as the unit
  runs.

This isn't waybar's built-in `idle_inhibitor` module. That one takes a Wayland
idle-inhibit lock on waybar's own surface — a perfectly good mechanism, but it
can only be toggled by clicking, with no IPC for a keybind to use, and it
wouldn't stop logind suspending the machine.

### No automatic sleep on mains power

Separate from the toggle above, and always on: while the machine is plugged
in, it never suspends on an idle timer. `modules/nixos/power.nix`, option
`local.power.noAutoSleepOnAC`, imported by `base.nix` so every host has it.

There is no single "auto-sleep" switch to flip, because automatic suspend can
come from more than one place and they don't know about each other. So this
holds a logind **idle** inhibitor for as long as a mains supply reports
`online`, and anything that asks logind — Plasma's powerdevil included — then
treats the session as busy. `ExecCondition` re-checks the power source each
time the unit starts, and a udev rule restarts it on any `power_supply` event,
so plugging and unplugging just re-evaluate the one condition. That check
follows systemd's own `on_ac_power()` rule — any supply that isn't a battery
and reports `online` non-zero — which is what makes a USB-C-charged laptop
(supply type `USB`, `online` 2) count as plugged in. A machine with no battery
at all counts as permanently on mains, so on the desk and the server the
inhibitor just stays up.

`--what=idle`, not `idle:sleep`, and that distinction is the whole point: a
*sleep* inhibitor blocks every suspend including a deliberate one, so
`systemctl suspend`, the session menu's "Suspend" and the lid switch would
all stop working. An *idle* inhibitor blocks only the timer-driven path.

Locking, dimming and blanking are untouched — those are swayidle under niri
and powerdevil under Plasma, and "don't fall asleep" is not "don't lock the
screen". On battery, nothing changes at all. The Plasma hosts also set
`powerdevil.AC.autoSuspend.action = "nothing"` directly, so the behaviour
doesn't rest on one daemon asking another the right question.

### The lid

Three cases:

| Lid closed… | What happens |
| --- | --- |
| on battery | suspend |
| on mains, nothing else attached | lock the session |
| docked | nothing |

**"Docked" is logind's own definition, and it's broader than a dock**: an ACPI
dock station reporting docked, *or* at least one external display connected.
Shutting a laptop that's driving a monitor is the case that wants nothing to
happen — the session stays up on the external screen rather than locking
behind a lid nobody was looking at.

The order those are tested in is what makes that hold, and it's logind's
rather than ours: docked first, then external power, then the plain case. A
dock supplies power, so the other order would never reach the docked rule and
a docked laptop would lock.

`modules/nixos/laptop.nix` owns the logind half — the three
`services.logind.settings.Login` keys. `HandleLidSwitchExternalPower` is
ignored entirely unless it's set, for backwards compatibility, so leaving it
out doesn't mean "do nothing on mains", it means mains falls through to
`HandleLidSwitch` and suspends. `lock` doesn't suspend: it asks every session
to lock, which under niri is swayidle's `lock` event running `lock-session`,
the same path `loginctl lock-session` takes. On battery the lock still happens
one step later, from swayidle's `before-sleep`, so the machine never resumes
unlocked either way.

`lock` and `suspend` differ in one place, and that's logind's doing rather than
a setting: while the lid stays shut logind keeps re-evaluating which of the
three cases applies, but the lock is only ever sent on the closing edge — a
no-op on those rechecks, or it would re-lock on every wakeup. So pulling the
monitor out of an already-closed laptop suspends it if that leaves it on
battery, and leaves the session as it was if it's still plugged in. Opening
and shutting the lid locks it.

The mains inhibitor from the section above doesn't get in the way, even
though "on mains" is exactly when it's held: `LidSwitchIgnoreInhibited`
defaults to yes, so lid handling ignores the high-level idle and sleep locks.
The low-level `handle-lid-switch` lock is always honoured, which is why
`Mod+Shift+I` still stops the lid doing anything at all.

What happens to the *panel* is niri's business rather than logind's, and it
lines up with the table: with an external monitor connected niri turns the
built-in one off when the lid shuts, so the docked case leaves a working
desktop on the monitor. With no external monitor it leaves the panel on —
disabling the only output would leave the session with nowhere to draw — so
the lock screen sits behind a closed lid until swayidle blanks it on its own
timer.

**Under Plasma, none of those keys fire.** powerdevil takes a block inhibitor
on `handle-lid-switch` at session start ("KDE handles power events") and
handles the lid itself, so the same three cases are restated for it in
`home/joshr/laptop.nix`: `lockScreen` on AC, `sleep` on battery, and
`inhibitLidActionWhenExternalMonitorConnected` for the docked case — powerdevil
has no docked profile, it has a per-profile "don't act when an external
monitor is connected", which is the same rule written from the other side.
The logind half still covers the greeter and a bare TTY there, which is why
both are set. Sleeping locks on the way back either way: that's
`kscreenlocker.lockOnResume` in `home/joshr/plasma.nix`.

It didn't always live in one place per session. `modules/nixos/niri.nix` set
the same three logind keys and disagreed with `laptop.nix`, and two modules
setting one option to different values is a conflict NixOS refuses to merge —
`laptop-niri` imports both, so that host could not evaluate at all. A lid is
hardware rather than a desktop session, which is why `laptop.nix` is where it
lives; `niri.nix` also runs on `gamestation-niri`, which has no lid.

### Displays

One file per host under `home/joshr/displays/`, kept separate so a monitor
change doesn't mean editing the session config. Empty means niri
auto-detects, which is what the laptop does.

```nix
# home/joshr/displays/gamestation.nix
local.niri.outputs = [
  { name = "DP-3"; mode = "2560x1440@180.000";
    position = { x = 0;    y = 0; }; focusAtStartup = true; }
  { name = "DP-2"; mode = "1920x1080@100.000";
    position = { x = 2560; y = 0; }; }
];
```

Get connector names and the modes each display actually reports with:

```bash
niri msg outputs
```

Three things worth knowing:

- **State the refresh rate.** A display's *preferred* mode is often not its
  fastest, so omitting it can silently leave a 180Hz panel at 60. The string
  has to match a mode the display reports or niri falls back and warns.
- **Positions are logical pixels**, so a scaled display occupies
  `width / scale`. Lay the next one out from there, not from its physical
  width. Above, DP-2 starts at x=2560 because DP-3 is unscaled.
- **niri has no "primary" display.** `focusAtStartup` decides where the
  session begins. To pin workspaces to a display, give them an
  `open-on-output` in the `workspace` declarations in `niri.nix`.

Also available per output: `scale`, `transform` (rotation),
`variableRefreshRate`, and `off`.

**The greeter does not follow the display config, deliberately.** Several
attempts to make it do so are gone; see "The login screen" below for why. The
greeter auto-detects, which lights up every connected display at kwin's choice
of mode and arrangement.


**Workspaces follow a display** via `local.niri.workspaceOutput` in the same
file. niri creates a workspace on whichever output is focused at the time, so
without it the numbered workspaces scatter across displays depending on where
you were when you first used each one. The desk pins them to `DP-3`.

### Brightness

The brightness keys worked on the laptop and did nothing on the desk for a
while, with the same package installed and the same binding on both. The
difference is hardware, not config.

`/sys/class/backlight` only ever contains **internal** panels — a display
whose backlight PWM the GPU driver owns. A monitor on DisplayPort or HDMI
never appears there, because its backlight is inside the monitor. So on a
desktop that directory is empty, and everything pointed at it silently does
nothing: the keys, and the pre-lock dim in `lock.nix` as well.

An external monitor is reached over **DDC/CI** instead, a small command set it
answers on the i2c bus alongside the video link. `modules/nixos/ddcci.nix`
loads `ddcci-backlight`, which speaks that in the kernel and registers each
monitor as an ordinary backlight device — so the existing keys and timers work
unchanged rather than needing a second code path.

```nix
# hosts/gamestation-niri/configuration.nix
local.backlight.ddcci.enable = true;
```

It needs a **reboot**, not just a switch — it's a kernel module. Then:

```bash
ls /sys/class/backlight/    # expect a ddcci* per monitor
ddcutil detect              # what DDC/CI itself can see
```

If a monitor is missing, check DDC/CI is enabled in its OSD — some vendors
ship it off, and call it "MCCS". If it's still missing, compare the adapter
names against `local.backlight.ddcci.busNameMatch`:

```bash
cat /sys/bus/i2c/devices/i2c-*/name
```

Buses are matched by name rather than probed blindly on purpose: most i2c
buses on a desktop are SMBus segments carrying RAM and RGB hardware, not
displays, and this machine already runs `acpi_enforce_resources=lax` so
OpenRGB can reach some of them.

Two things worth knowing:

- **DDC/CI is slow** — a write is a round trip on the order of 100ms per
  display, where a laptop panel is instant. The `brightness` helper
  (`scripts.nix`) drops overlapping presses rather than queueing them, so a
  held key doesn't keep climbing after you let go.
- **The keys drive every display**, which is why they call that helper and
  not `brightnessctl` directly. `brightnessctl` with no `--device` adjusts
  the *first* device it finds — invisible with one internal panel, wrong
  with one device per monitor.

The OSD that comes up with the keys reports the *first* device's level, read
back after the write. On the laptop that is the only device there is, and on
the desk every display has just taken the same step — but they can still drift
apart, if a monitor refuses a write or gets adjusted from its own buttons, and
what you get then is one display's real level rather than an average of two
that belongs to neither. See "The on-screen display".

Not enabled on the Plasma variant of the desk. It would work, but it would
also hand powerdevil's idle timer real dimming on displays it currently can't
touch.

### The login screen

**SDDM uses its own built-in greeter**, not a theme of ours. That is
`local.sddm.theme = "stock"`, and it is the default after the themed one left
the primary display black.

The evidence for blaming the theme is that the failure did not move. It was
identical under kwin_wayland, under weston and under X11, and SDDM logged no
error at any point in the process:

```
sddm[1734]: Greeter starting...
sddm-helper[1766]: [PAM] Starting... / Authenticating... / returning.
sddm[1734]: Greeter session started successfully
sddm[1734]: Message received from greeter: Connect
```

The greeter started, authenticated and connected. Three different display
servers failing the same way, with the stack reporting success, points away
from all three and at the one component they share.

Things ruled out along the way, so they are not tried again:

- **A generated `kwinoutputconfig.json`** from `local.niri.outputs`. Removed.
  Writing a mode can black-screen a display outright, because kwin hands it
  straight to a modeset and a rate that doesn't match exactly — DRM reporting
  179998 mHz where the config says 180000 — simply fails. Dropping the mode
  didn't help either: with no config, kwin still picks the preferred mode,
  which for a 1440p180 panel is 180Hz.
- **Copying KWin's own file** from the Plasma session. That dragged a whole
  arrangement across including its enabled/disabled state.
- **The greeter's compositor.** weston made no difference, and neither did
  X11.

The stock greeter confirmed the diagnosis: it comes up fine on both displays,
so the theme was indeed the thing at fault.

**`local.sddm.theme = "astronaut"`** brings the themed greeter back — one
`sddm-astronaut` build per palette, following the desktop's theme and
wallpaper — with the leading suspect now fixed.

That suspect is the background. The theme config points `Background` at a
fixed runtime path, `/var/lib/sddm-theme/wallpaper.png`, and that file only
appears once the wallpaper switcher has run. Before a wallpaper has ever been
picked, it isn't there. sddm-astronaut then feeds a missing image into a blur
shader — `PartialBlur` is on — and a QML scene graph that fails while building
an effect chain renders *nothing*, rather than falling back to
`BackgroundColor`. That matches every symptom: no error from SDDM, which had
already logged the greeter as started and connected, and identical behaviour
on every display server, because none of them were involved.

The fix is that the sync service now guarantees the file exists, seeding a
solid image in the palette's background colour when there's no wallpaper to
convert. A few KB per palette.

This is unproven — the greeter's own QML warnings were never captured — but it
was the only path in the theme referencing a file that might not exist. If the
themed greeter is still black, go back to `"stock"` and the next thing to
strip is the per-palette directory rename.

One thing that has to happen on the way to stock: the sync service deletes
`/etc/sddm.conf.d/99-niri-active-theme.conf`. That drop-in names a
`niri-<palette>` theme package, it lives in `/etc` where NixOS only removes
what it declares, and left behind it would point SDDM at a theme directory
that is no longer in the store. The service is ordered before
`display-manager.service` so this lands before the greeter reads it, rather
than one boot late.

**The greeter's cursor** comes from `settings.Theme.CursorTheme`. SDDM ships
no cursor of its own — it exports `XCURSOR_THEME`/`XCURSOR_SIZE` into the
greeter, which looks the name up on the *system* icon path. Without them the
greeter inherits whatever the compositor defaults to, which on a bare login
screen is often nothing, and the pointer is invisible.

It's set to `Bibata-Modern-Ice` at size 24, matching `home.pointerCursor` in
`home/joshr/home.nix` so the pointer doesn't change shape at login. The two
have to be stated separately: the greeter runs as the `sddm` user before
anyone has logged in and cannot see home-manager's config. `bibata-cursors` is
in `environment.systemPackages` (`modules/nixos/base.nix`), which is what puts
it on the system icon path — a cursor theme only in the user profile would not
be found.

If the login screen is ever black again, a TTY still works (`Ctrl+Alt+F2`), as
does booting the previous generation.


### Screenshots

Region capture goes `slurp` → `grim` → `satty`, so you land in an annotation
editor (arrows, boxes, blur, text) and it copies to the clipboard on save.
Plain screen and window capture use niri's built-in `screenshot-screen` and
`screenshot-window` actions instead — the compositor already knows the exact
geometry, so there's nothing for a script to compute wrong.

**`Shift+Print` (or `Mod+Ctrl+S`) re-shoots the last region** with no selection
step. Every region capture writes its geometry to
`~/.local/state/niri-screenshot/region`, and that mode reads it straight back.
It's for shooting the same frame repeatedly — a panel, a window, a chart being
tweaked — where redrawing the box by hand is both the tedious part and the
reason successive shots don't line up.

It falls back to a normal selection if there's no remembered region yet, or if
the region no longer captures — a monitor unplugged or the layout rearranged
under it. The geometry is only remembered once `grim` has accepted it, so a
region that can't be captured never becomes the one it comes back to.

Note that this is a separate keybind rather than "reopen slurp with last time's
box ready to adjust", because slurp can't pre-fill a selection. Its `-r` reads
boxes on stdin and *restricts* selection to them, so handing it the saved region
would let you click that box to accept it but never drag its edges — a worse
version of the same thing, with an extra click.

### Lock screen

`swaylock-effects` with a blurred screenshot background, ring colours from
the active theme. `swayidle` dims at 4 minutes, locks at 5, blanks at 6, and
locks before suspend.

The lock script passes `--color` as well as `--screenshots`, and that is
load-bearing rather than decorative. `--color` is the flat colour swaylock
paints underneath the screenshot, so it is what you see when there is no
screenshot to draw over it — and its default is **white**. Locking with a
monitor already blanked is exactly that case: `--screenshots` grabs each
output through wlr-screencopy, and a capture of a powered-off output fails.
The packaged fork then clears the screenshot flag on its shared state instead
of on the surface that failed, so one blanked monitor drops the screenshot
background on *every* display and the whole lock screen comes up white.
Pointing `--color` at the theme background makes that fallback a themed solid
colour. It is easy to hit because blanking and locking are independent —
`Mod+Escape` blanks on demand, and swayidle blanks at 360s and locks before
sleep.

niri's `layout { background-color }` does not help here: that is the backdrop
behind windows, and swaylock's own surface covers it.

**swaylock is patched** (`home/joshr/niri/swaylock-date-fit.patch`) so the date
stacks onto two lines — weekday over month and day — and can't overhang the
ring.

Upstream draws the date as one row sized at a hardcoded `arc_radius / 6`, so it
grows in exact proportion to the circle: a long date like "Wednesday, September
24" hangs over by the same fraction at *every* radius, and widening
`--indicator-radius` buys nothing. No flag reaches it either — `--font-size`
sets the clock above it, and the date's divisor isn't exposed. Without the patch
the only fixes available in configuration are to shorten the date or narrow the
font, and the installed fonts are FiraCode and Poppins with nothing condensed.

The patch splits `--datestr` on a newline (strftime `%n`, hence
`--datestr "%A%n%B %d"`) and stacks the halves. Two short lines fit at full size
where one long one didn't: at radius 130 "Wednesday" and "September 24" measure
117px and 156px against chords of 246px and 231px, where the single row was
299px against 240px. It also scales a line down if it still wouldn't fit,
bounded by the ring's inner chord at that line's own baseline rather than the
diameter — with stacking that never triggers here, it's the backstop that makes
an overhang impossible for any format or locale.

It costs a source build of swaylock-effects, which is a small C project and
quick. If a nixpkgs bump moves those lines the patch will fail to apply — the
fallback is a one-line `--datestr` short enough to fit.

**`Mod+Escape` blanks the monitors on demand**, from the lock screen as well
as from the desktop — for when you're walking away now and don't want to wait
out the idle timer. Any input wakes them; on the lock screen that leaves
swaylock exactly where it was, so it's a screen-off, not an unlock.

It works through the lock without an `allow-when-locked` on it because niri
keeps a whitelist of actions that survive the lock screen —
`power-off-monitors` is on it, which is the same reason the 6-minute blank
above fires while locked. Setting that property here would actually be a
config *error*: niri only accepts it on `spawn` binds.

It's `Mod+Escape` and not bare `Escape` because niri intercepts a bound key
unconditionally — it matches binds before it looks at the lock state, and
only then drops the action if the session is locked. A bare `Escape` bind
would therefore swallow Escape in every application all the time, and there
is no "only while locked" flag to scope it with.

The system module adds `security.pam.services.swaylock` — without that PAM
entry swaylock accepts your password and then rejects it, which locks you out
of your own session.

### RGB lighting

The OpenRGB daemon is a system service (`modules/nixos/gaming.nix`); the niri
session starts its tray applet at login and applies a profile:

```nix
local.openrgb.profile = "main";   # ~/.config/OpenRGB/main.orp
```

Profiles are made from OpenRGB's own UI ("Save Profile") and are runtime
state, not something this repo writes — naming one that doesn't exist yet is
harmless, OpenRGB says so and carries on. The applet is launched with
`--startminimized`, which is load-bearing twice over: OpenRGB drops to CLI
mode and *exits* as soon as it's given any option, so `--profile` on its own
would set the lighting and quit with no tray icon. `--startminimized` implies
`--gui` and keeps the window out of the way.

`local.openrgb.monochromeIcon` (on by default) swaps the multicolour logo for
a plain one. It reaches the **launcher** icon only: OpenRGB loads its tray
icon from a pixmap compiled into the binary rather than looking it up in the
icon theme, so nothing outside the package can change that one. Upstream has
an open request for it (OpenRGB issue #2453).

## Wallpapers

`~/.local/share/wallpapers` has two halves. The collection out of the
dotfiles repo is the permanent one. Beside it, `WallhavenFlake/` holds
[wallhaven.cc](https://wallhaven.cc)'s current top 20 — and only those
twenty, so as the toplist moves on, the folder moves with it.

Both desktops pick the new files up for free: niri's `Mod+Ctrl+W` picker globs
the whole tree, and Plasma's slideshow is pointed at the same directory.

### Which twenty, and who decides

A flake input:

```nix
wallhaven-toplist = {
  url = "file+https://wallhaven.cc/api/v1/search?categories=111&purity=100&sorting=toplist&topRange=1M&order=desc&atleast=1920x1080&ratios=16x9%2C16x10";
  flake = false;
};
```

That's the API's JSON search response — the **list**, not the images. Nix
fetches and hashes it like any other input, which is the whole point of doing
it this way: the twenty are pinned in `flake.lock`, the desk and the laptop
show the same twenty, and they change when you run `nix flake update` rather
than whenever wallhaven's front page does.

```bash
nix flake update --refresh wallhaven-toplist
```

`--refresh` because Nix caches fetched files for an hour and will otherwise
hand back the copy it already has. That's for re-locking the *same* URL —
editing the query is a different input entirely, and the next evaluation
re-locks it on its own. Commit the resulting `flake.lock` alongside the edit.
`file+https` rather than plain `https` because the plain form is the *tarball*
fetcher, which would try to unpack a JSON document.

The query is the website's Toplist view: all three categories (`111`), SFW
only (`100`), ranked over the last month, nothing below 1080p, and — via
`ratios` — widescreen only. Edit it and re-lock to change what "top 20"
means: drop `atleast` for the unfiltered list, `topRange=1d` for today's.
How many to keep is separate, and is `local.wallhaven.count` (1–24, the size
of one API page).

**`ratios=16x9,16x10`** is the widescreen filter. Both displays on the desk
are 16:9 — 2560x1440 and 1920x1080 — so 16:10 is the widest miss worth
taking, losing a sliver off the top and bottom when it scales. Anything
squarer arrives pillarboxed or cropped hard by whichever of awww or Plasma is
drawing it. The laptop panel isn't pinned in this repo at all
(`home/joshr/displays/laptop.nix` is deliberately empty), so it isn't what
the filter is measured against — `16x10` covers it if it happens to be one.

Two things about that parameter are easy to get wrong. It takes a
comma-separated list, but wallhaven's `landscape` supergroup is *not* the
same request — that's every non-portrait ratio it knows, `4x3` and `5x4`
included, which means "not portrait" rather than "wide". And the ultrawide
ratios (`21x9`, `32x9`) are left out deliberately: there's no display here to
put them on, and on a 16:9 panel they letterbox to a strip.

The comma is written `%2C` in `flake.nix`. Nix parses the query into
parameters rather than passing the URL through verbatim — you can see it
re-emit them alphabetically in `flake.lock` — so encoding the separator keeps
it unambiguously part of the value. wallhaven decodes it back on receipt.

A narrower query is drawn from a smaller pool, so a month with an unusually
vertical toplist can return fewer than `local.wallhaven.count` images.
Nothing breaks — the sync script takes what's there — the folder is just
occasionally short.

### Why the images aren't in the store

A flake input is one URL locked by one hash. The twenty image URLs aren't
known until that JSON has been fetched and read, by which point evaluation is
already under way — and wallhaven publishes no checksum for the files
anywhere in its API, so there is nothing for `pkgs.fetchurl` to verify even
if the URLs were known in time.

So the list is declarative and the files are not. `home/joshr/wallhaven.nix`
builds a `wallhaven-sync` script around the locked JSON; home-manager runs it
at activation and again at login (`wallhaven-wallpapers.service`), and you can
run it by hand. It downloads what the list names, deletes everything it
doesn't, and is careful in the two ways that matter:

- **It won't prune after a failed download.** Deleting yesterday's twenty
  because the network dropped halfway through would leave the picker emptier
  than it started. A run with any failure keeps everything and exits non-zero;
  the next one finishes the job.
- **It checks the JSON is a search response before believing it.** `nix flake
  update` will pin an error page as happily as a result set, and an error page
  parses as "zero wallpapers".

Files are named for wallhaven's id, so a wallpaper that merely slides from 3rd
to 5th place isn't downloaded again. A run with nothing to fetch touches the
network zero times — the list is a local store path by then.

The practical consequence of all this: a machine that hasn't had network since
the last `nix flake update` still shows the previous twenty. It isn't broken,
it just hasn't caught up. `wallhaven-sync` when it's back online.

### The one-off directory change

`~/.local/share/wallpapers` used to be a single symlink to the dotfiles'
wallpaper directory in the store. It's now a real directory of per-file links
(`recursive = true` in `home/joshr/home.nix`), because a read-only store path
has nowhere to put `WallhavenFlake/`.

Switching between those two shapes is not something home-manager handles on
its own — with the old symlink still there, every wallpaper's target resolves
*through* it into the store, and the linker spends the switch trying to back
up files it cannot move. So `wallhaven.nix` removes the stale link first, once,
before the linking phase. It only does this for a symlink pointing into the
store; one you made yourself, to another disk say, is left alone with a
warning.

### What the first rebuild will do

`flake.lock` has no `wallhaven-toplist` entry yet — wallhaven.cc was not
reachable from where this was written, so there was nothing to hash. Nix adds
the entry itself on the first evaluation that has network; commit the result
like any other lock change.

That also means the response shape was matched against wallhaven's documented
API (`data[].path`, one page of 24) rather than a live call. The sync was
exercised end to end against a stand-in server — fresh sync, toplist rotation,
mid-run download failure, an error page in place of a listing — but not
against wallhaven itself. If a field has moved since, the failure is the loud
kind: `wallhaven-sync` says "not a wallhaven search response", exits non-zero
and changes nothing.

## Dates and times

12-hour clock, month before day, everywhere. There is no single setting for
this — every clock either carries its own format string or asks the locale —
so it is set in each of them, and they're listed here because that's the only
way to find them all again:

| where | file | format |
|---|---|---|
| locale (`date`, `ls -l`, anything that asks) | `modules/nixos/base.nix` | `LC_TIME = en_US.UTF-8` |
| waybar clock | `home/joshr/niri/waybar.nix` | `%I:%M %p   %a, %b %d` |
| swaylock | `home/joshr/niri/scripts.nix` | `%I:%M %p`, `%A, %B %d` |
| SDDM greeter | `modules/nixos/niri.nix` | `h:mm AP`, `dddd, MMMM d` |
| Plasma panel clocks | `home/joshr/plasma.nix` | `time.format = "12h"` |
| screenshot filenames | `niri.nix`, `scripts.nix` | `%m-%d-%Y %I-%M-%S %p` |

Two things worth knowing before editing any of them:

- **waybar is not strftime.** It formats through libfmt/date.h, so glibc's
  `%-I` "no padding" extension doesn't exist there — it comes out as a
  literal `-I` or throws the whole format away. Hence `07:30 PM` rather than
  `7:30 PM` in the bar. SDDM is Qt format, which is different again: `h`
  means 12-hour as soon as an `AP` field is present.
- **Screenshot filenames no longer sort chronologically.** `%m-%d-%Y` puts
  every January together. That's the cost of matching the rest of the system;
  if you'd rather have sortable names back, `%Y-%m-%d %H-%M-%S` is the string
  to restore, in both `niri.nix` and `scripts.nix`.

## The browser

**Vivaldi**, on every host. `home/joshr/browser.nix` installs it, sets
`$BROWSER`, and is the one place that decides which browser is *the* browser.

Firefox is still installed and still themed (`home/joshr/firefox.nix`) — it
held the default for a while, and the notes below are what it is still good
for. It simply isn't what links open in any more.

One detail that bites: nixpkgs copies Vivaldi's upstream `.deb` desktop entry
across **without renaming it**, so the entry ID is `vivaldi-stable.desktop`,
not `vivaldi.desktop`. Naming the wrong one fails silently — `mimeapps.list`
keeps whatever string you give it and `xdg-open` just finds nothing. Both
spellings are listed wherever the format takes a fallback list.

Both sessions get it the same way now: **`modules/nixos/default-apps.nix`**,
which writes `/etc/xdg/mimeapps.list`. `kdeglobals.General.BrowserApplication`
in `home/joshr/plasma.nix` is still set and still agrees.

### File associations, and why they're in /etc

This used to be home-manager's `xdg.mimeApps`, which owns
`~/.config/mimeapps.list` and writes it as a read-only symlink into the store.
That is the same file every interactive "make this the default" writes to —
Dolphin's "Open With… → Remember application association for this type of
file", KDE's File Associations panel, Plasma's Default Applications page, "set
as default" inside a browser. With home-manager holding it, **all of them
appear to work and none of them persist.** Images kept reverting; the checkbox
looked like it worked and the association was gone by the next launch.

It was also why the Plasma hosts were deliberately kept away from
`xdg.mimeApps` — under a running Plasma it breaks the settings page outright.

So the declarations moved down a level. The XDG mime-apps spec reads, in order
of decreasing precedence:

```
$XDG_CONFIG_HOME/$desktop-mimeapps.list
$XDG_CONFIG_HOME/mimeapps.list      <- the user's; nothing manages it now
$XDG_CONFIG_DIRS/$desktop-mimeapps.list
$XDG_CONFIG_DIRS/mimeapps.list      <- modules/nixos/default-apps.nix
```

`$XDG_CONFIG_DIRS` is `/etc/xdg`, so the declared defaults apply on a fresh
install and on every rebuild, while anything picked in a GUI lands in the
user's own file and outranks them. Declarative defaults *and* a settings panel
that works, rather than one at the cost of the other. It also removed the
reason the two sessions were configured differently.

`[Default Applications]` is honoured there specifically because `/etc/xdg` is a
*config* directory — the spec only reads that group from `$XDG_CONFIG_HOME` and
`$XDG_CONFIG_DIRS`, which is why this isn't in a data dir.

Note that **System Settings alone would not have fixed any of this.** It ships
no KCMs; it's the shell they load into. The File Associations panel
(`kcm_filetypes`, plus the standalone `keditfiletype` that Dolphin's properties
dialog opens) is in `kde-cli-tools`, which the niri profile now installs.
Default Applications (`kcm_componentchooser`) is in `plasma-desktop`, which is
deliberately not pulled in — it's a large chunk of Plasma, and that panel only
covers the browser/email/terminal/file-manager four rather than file types.

### Why Firefox is still here

The requirement when it took over was cloud sync, a Chromium or Firefox base,
and colours that follow the desktop theme. Firefox is the only candidate that
does all three without a workaround:

- **Sync** is Firefox Sync over a Mozilla account — first-party, end-to-end
  encrypted, carrying bookmarks, history, open tabs, logins, add-ons and
  preferences between the desk and the laptop with no server of your own.
  Sign in from the toolbar's account button; nothing about it is configured
  here beyond leaving `identity.fxaccounts.enabled` alone.
- **Theming** is the part that ruled the others out. A Chromium UI takes its
  colours from a signed theme extension or from GTK, and neither reads a file
  you generate. Vivaldi *can* take arbitrary colours, but only through its own
  settings UI, into a preferences blob that isn't declarative and can't be
  repointed at a symlink. Firefox reads `chrome/userChrome.css` out of the
  profile directory at startup, so it plugs straight into the mechanism
  already in place for everything else.

### How it follows the theme

`themes.nix` grows two more generated files per palette,
`firefox-userChrome.css` and `firefox-userContent.css`, and
`home/joshr/niri/firefox.nix` symlinks the profile's `chrome/userChrome.css`
and `chrome/userContent.css` at the active theme — the same out-of-store
symlink trick as `kdeglobals`. Tab strip, toolbars, address bar, menus,
sidebar, findbar and the `about:` pages all end up on the palette's ten
colour roles, with the accent on the selected tab and the focused address
bar, exactly like niri's focus ring and waybar's active workspace.

Two honest caveats:

- Firefox reads those stylesheets **once, while it starts**. There's no
  supported way to make a running Firefox re-read them, so a theme switch
  lands at the next launch — same as Dolphin, unlike kitty and waybar which
  the switcher can nudge.
- `userChrome.css` works against Firefox's internal CSS variables, not a
  documented config format. The names have been stable since the Proton
  redesign, but they aren't API. If an update renames one, that surface falls
  back to the built-in dark theme rather than breaking; the fix is to diff
  against `browser.css` in the new version.

All of that is niri-only, for the same reason the kitty `include` is: the
Plasma hosts have no theme state for the symlinks to point at, so there
Firefox wears its own dark theme and takes its accent from Plasma like any
other GTK app.

Note `home/joshr/niri/firefox.nix` is currently not imported by
`home/joshr/niri/default.nix`, so the stylesheet symlinks aren't in place.
Uncomment it there to turn Firefox's theming back on; the `xdg.mimeApps`
block that used to live in it has moved to `./browser.nix`, so the two won't
collide.

### What Nix owns and what Sync owns

Nix owns the *shape* of the browser — which prefs are set, that custom
stylesheets are on, that it handles `http(s)`. Sync owns the *contents* —
bookmarks, history, tabs, logins, add-ons.

That split is deliberate. Declaring add-ons here would need the NUR or the
firefox-addons flake, and would then fight Sync every time the two disagreed:
Nix would reinstall on the desk what you removed on the laptop. The prefs in
`firefox.nix` are written to `user.js`, which Firefox re-applies on **every**
start, so where the two overlap the declared value always wins. The practical
rule: anything you want to change from inside the browser and have stick must
not be listed in `firefox.nix`.

## Bootloader

`local.boot.loader` picks one of three, in `modules/nixos/boot.nix`:

| | themed | finds other OSes by |
|---|---|---|
| `limine` (default) | wallpaper + full palette, follows runtime switches | scanning every ESP on the machine for other loaders |
| `grub` | palette + fixed splash, build time only | `os-prober` |
| `systemd-boot` | not at all | itself, no setting needed |

limine is the default because it's the only one that can put the desktop's
wallpaper and colours on the boot menu. grub is the fallback for anything it
can't handle — BIOS/MBR, odd partition layouts, firmware that dislikes
limine's EFI binary — and it still detects *more*, since os-prober looks
inside other partitions rather than only at EFI System Partitions.
systemd-boot is the escape hatch and what this repo used before the module
existed:

```nix
local.boot.loader = "systemd-boot";
```

**Changing this rewrites how the machine boots.** Do it on a rebuild you can
watch, with install media to hand. The previous generation stays in the *old*
loader's menu — but only while that loader is still installed and still the
one your firmware runs.

### Dual boot: finding the other operating systems

**On by default.** `local.boot.detectOtherSystems = true` is the setting, and
under limine the scan runs in two passes:

1. **This machine's own ESP.** That is the whole story for a dual boot where
   both systems share one EFI System Partition, which is what you get when
   they're installed onto the same disk.
2. **Every other ESP attached to the machine**, behind
   `local.boot.scanAllEsps` (also on by default). NixOS mounts exactly one
   ESP, so an OS installed onto a disk of its own is otherwise invisible.
   Each is located by GPT partition type, mounted read-only, read, and
   unmounted. Nothing is written, and the service runs with `PrivateMounts`
   so a mount can't outlive the scan even if it's killed mid-way.

Whatever it finds appears under an **"Other operating systems"** branch in the
boot menu — one chainload entry per vendor directory that carries a
recognised loader (`bootmgfw.efi` for Windows, `shimx64.efi` or `grubx64.efi`
for a distro, rEFInd, elilo). Entries on this machine's ESP are addressed as
`boot():/…`; entries on any other are addressed by filesystem UUID, since
`boot()` only ever means the volume limine itself was loaded from.

To see what it found without rebooting:

```bash
sudo systemctl start limine-theme-sync
grep -A100 'detected systems' /boot/limine/limine.conf
```

Nothing found? The scan only reads EFI System Partitions. An OS whose loader
isn't on one — an old BIOS/MBR install, or a distro on an LVM or LUKS volume
with no ESP of its own — needs grub, whose `os-prober` inspects partitions
rather than boot partitions:

```nix
local.boot.loader = "grub";   # detects more, but no runtime theming
```

To turn detection off entirely, or to leave other disks alone:

```nix
local.boot.detectOtherSystems = false;   # no other-OS entries at all
local.boot.scanAllEsps = false;          # this machine's ESP only
```

### How the boot menu ends up wearing the desktop's colours

The menu is drawn before any of the desktop exists, from a text file on the
EFI System Partition. So the palette and wallpaper are *pushed* there ahead of
time, the same way the SDDM greeter is fed, and for the same reason: the thing
being themed can't read your home directory.

The NixOS limine module regenerates `<esp>/limine/limine.conf` on every
rebuild, so a runtime edit can't just go anywhere in it. What makes it work is
that the module emits two verbatim blocks at known ends of the file —
`extraConfig` first, `extraEntries` last. Each gets a sentinel-delimited
region, filled at build time with the default palette and no detected systems.
`limine-theme-sync` then rewrites the *inside* of each region, running at
boot, whenever you pick a theme or wallpaper, and at the end of every
bootloader install. If it never runs, the menu is still valid and still
themed, just with the default palette.

The regions sit where they do because limine's config has no separator between
global options and menu entries: an entry is opened by a line starting with
`/` and swallows every option after it. Theming keys are global and must go
above the first entry; detected-OS entries must go below the NixOS ones.

Three things keep this from being a way to brick the machine, and all three
are enforced in the module:

- **`enrollConfig` stays off.** Enrolling hashes the config into the limine
  binary; a rewritten file then fails its own integrity check and you stop at
  the bootloader. This is the one setting that turns a cosmetic feature into
  an unbootable system.
- **The wallpaper lives outside `<esp>/limine/`.** The installer walks that
  directory and deletes every file it didn't itself write, so an image parked
  there survives exactly until the next rebuild.
- **The config never names a wallpaper that isn't there.** Both the build-time
  block and the sync emit the `wallpaper:` line only alongside a file that
  exists.

`style.wallpapers` and the `style.graphicalTerminal.*` options are deliberately
left alone — they'd write the same keys from build-time values, duplicating
every line, and `style.wallpapers` additionally appends a BLAKE2b hash of the
image to the path, which is exactly what stops a file being swapped underneath
it at runtime.

Detection is ESP-only under limine: an OS on a disk that isn't mounted here
won't be seen, and a distro shipping both shim and grub is listed once (shim
wins — it's what boots under Secure Boot and hands over to grub itself).

```nix
local.boot.detectOtherSystems = false;   # skip the scan entirely
local.boot.wallpaper = ./some.png;       # menu image before niri picks one
local.boot.branding = "gamestation";     # text above the menu
local.boot.menuTransparency = "50";      # TT of limine's TTRRGGBB
```

## Shells

Fish is the login shell for both `joshr` and `root`, but zsh, bash and
nushell are all installed and configured too, and **all four get the same
starship prompt** from `home/common/files/starship.toml`.

Two things are needed for that, both in `home/common/shell.nix`. starship's
`enable*Integration` options already default to `true`, but all they do is
set the corresponding `programs.<shell>` options — and home-manager only
writes a shell's rc file when that shell's own module is enabled. So the
shells are enabled explicitly alongside the integrations; with only one half,
the prompt silently doesn't appear.

Note that only fish carries the eza aliases (`ls`, `ll`, `la`, `lt`, `lg`) —
those came from the dotfiles' `config.fish.tmpl` and haven't been mirrored
into the other shells.

### `nix-clean`

Also fish-only, and also in `home/common/shell.nix`, so `joshr` and `root`
both get it. It's the on-demand version of the weekly garbage collection in
`modules/nixos/base.nix`, for when you want the space back now:

```fish
nix-clean          # generations older than 7d, matching the weekly timer
nix-clean 30d      # any age nix-collect-garbage accepts
nix-clean all      # every generation but the current one
```

It runs `nix-collect-garbage` **twice**, and that's the point of it. The tool
only walks the profiles it can see, and which profiles those are follows
`$HOME`. The `sudo` run gets the system profile — old kernels, initrds and
system closures, which is where the space actually is — but root's `$HOME` is
`/root`, so it never reaches `~/.local/state/nix/profiles`, where
home-manager keeps joshr's generations. Sweep only the system half and those
stay pinned as live GC roots, holding their whole closures down with them.
The second run is skipped when you're already root, where it would just
repeat the first.

The current generation always survives, both here and under `all`. What you
spend is rollback: picking a previous generation from the boot menu is the
recovery path for a bad switch, which is why `all` has to be asked for by
name. Deleted generations also stay *listed* in the menu until the bootloader
config is regenerated, so the function ends by reminding you to
`sudo nixos-rebuild boot --flake /etc/nixos#<host>` — and `<host>` there is
the flake attribute, not the hostname. On this machine those differ:
`gamestation` and `gamestation-niri` both run on a box called `dialga`.

## Development environments

Both machines are set up so that **no language toolchain is installed
globally**. Python, node, a Rust compiler, JDKs, `gcc`, database clients —
none of it lives in the user profile. Each project declares what it needs in
its own `flake.nix`, and direnv puts those tools on `PATH` when you `cd` in
and takes them away again when you leave.

That's not asceticism. Two projects wanting different Python minor versions
is the normal case, and the moment toolchains are global, the second one is a
problem to be worked around. Per-project shells make it a non-event, and the
declaration travels with the repo, so the laptop and the desk agree without
either being configured for that project at all.

### One import, and it's off by default

All of it lives in **`modules/nixos/development.nix`**, and the import line is
**commented out in every desktop host**. Uncomment it on the machines you
actually develop on:

```nix
# hosts/gamestation/configuration.nix
    # ../../modules/nixos/development.nix     <- delete the #
```

`server` is the exception — it imports the module for real, since a headless
box is where containers and a remote `nix develop` are the point.

Note what that costs when it's off: **Docker goes with it.** The old
`modules/nixos/virtualisation.nix` had nothing in it but Docker and
docker-compose, so it was folded in here rather than left as a second thing to
remember. There's no finer granularity on purpose — one switch, one mental
model. `joshr`'s membership of the `docker` and `libvirtd` groups follows the
daemons automatically (`modules/nixos/users.nix`), so a host with the module
off doesn't fail activation naming groups that don't exist.

**VMs are a separate import.** QEMU/KVM and virt-manager used to be in here
too, and are now `modules/nixos/virtualization.nix`, added per host the same
way:

```nix
# hosts/gamestation-niri/configuration.nix
    ../../modules/nixos/virtualization.nix
```

Both are "virtualisation" in the NixOS option tree, which is how they ended up
in one file, but they aren't one decision: libvirtd is a daemon, a bridge
interface, swtpm and a GUI app, and wanting containers on a box is a poor
reason to be handed all of that. The group membership works the same way —
`users.nix` keys off `config.virtualisation.libvirtd.enable`, so importing one
module and not the other is fine.

What that one turns on: **libvirtd** with `qemu_kvm` and `runAsRoot = false`
(the failure mode of the other setting is a guest escape being a root escape);
**swtpm**, the software TPM a Windows 11 guest insists on; **virt-manager** as
the GUI, via `programs.virt-manager` rather than the bare package because the
module also enables the dconf settings it keeps its connection list in; **SPICE
USB redirection**, so a passed-through YubiKey or flash drive reaches the
guest; and `virtiofsd` + `spice-gtk` for host directory sharing and the console
client.

What the module turns on:

- **direnv** with **nix-direnv**, hooked into bash, zsh and fish. Plain direnv
  re-evaluates `use flake` from scratch on every `cd`, which for a flake means
  seconds each time; nix-direnv caches the built profile and only
  re-evaluates when `flake.nix` or `flake.lock` change. It also plants a GC
  root in `.direnv/`, so the weekly `nix-collect-garbage` in `base.nix` can't
  delete a shell you're still using.
  - This is the NixOS module, not home-manager's, so the whole story is one
    import. The one gap is **nushell** — the NixOS module doesn't hook it.
  - Per-user tuning (`hide_env_diff`, `warn_timeout`) is a
    `~/.config/direnv/direnv.toml` thing that no system module can set.
- **Docker** + docker-compose.
- **`dev-init`**, the one-command path below.
- The nix settings the rest depends on, all of which need root: `keep-outputs`
  and `keep-derivations`, without which garbage collection deletes the *build*
  inputs of a dev shell (a shell isn't a package, so nothing points at its
  output); `trusted-users = [ "root" "@wheel" ]`, without which `cachix use`
  can't write a substituter; and `log-lines = 25`, because ten lines of a
  failed builder's output usually isn't the part that says what went wrong.
- Language-agnostic tools: `nil`, `nixfmt`, `nix-output-monitor`,
  `nix-tree`, `cachix`, `just`, `jq`, `yq-go`, `ripgrep`, `fd`, `lazygit`,
  `gnumake`. Nothing language-specific — a compiler or an interpreter goes in
  the project's own devShell.

### The one-command path

In the project directory:

```bash
dev-init            # generic skeleton
dev-init python     # or: node, rust, go
```

That copies a template's `flake.nix`, `.envrc` and `.gitignore` in and marks
the `.envrc` trusted, so the shell is built and entered at the prompt you get
back. Commit all three files — the whole point is that the next machine gets
the same environment by cloning.

`dev-init` refuses to run where a `flake.nix` already exists rather than
overwrite one.

### The manual path

Two files. `flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ python312 postgresql ];

        # Exported on entry, gone on exit.
        env.DATABASE_URL = "postgres://localhost/dev";

        shellHook = ''
          echo "ready"
        '';
      };
    };
}
```

and `.envrc`:

```
use flake
```

Then `direnv allow`. direnv refuses to run an `.envrc` it hasn't been told to
trust — that message on first entry, and after every edit, is the safety
check working, not a failure.

### Day to day

| | |
|---|---|
| add a tool | put it in `packages`, save; direnv rebuilds on the next prompt |
| find the attribute name | `nix search nixpkgs ripgrep`, or search.nixos.org |
| pin the exact versions | commit `flake.lock` — it's what makes the shell reproducible |
| update them | `nix flake update`, or `nix flake update nixpkgs` for one input |
| force a rebuild | `direnv reload` |
| run one command without entering | `nix develop -c pytest` |
| a second shell (e.g. CI) | `devShells.${system}.ci = ...`, entered with `use flake .#ci` |

Anything the project writes at runtime — a venv, `node_modules`, `GOPATH` —
stays inside the project directory. The templates set that up and ignore the
paths in `.gitignore`, because the Nix store is read-only and the alternative
is a tool failing halfway through an install with a confusing error.

### Secrets

Don't put them in `flake.nix` — it goes in the store, world-readable. Use a
gitignored `.env` and read it from `.envrc`, which direnv evaluates on your
machine and never copies anywhere:

```bash
# .envrc
use flake
dotenv_if_exists .env
```

### A project that isn't yours

Most repos don't ship a flake. Add one anyway — `dev-init` in a clone works
fine, and `flake.nix`, `.envrc` and `.direnv/` can stay out of the repo's
history via `.git/info/exclude` if you'd rather not commit them upstream.

If a project has a `shell.nix` or `default.nix` already, skip the flake
entirely and let direnv use it:

```
# .envrc
use nix
```

And when the dependency really is a whole service rather than a binary —
Postgres, Redis, a message queue — reach for Docker Compose instead; both
hosts have it via `modules/nixos/virtualisation.nix`. A dev shell is for
tools, not daemons.

### VS Code

The editor has to be told about direnv, or it sees the bare system `PATH` and
reports every import in the project as unresolved. `mkhl.direnv` is in the
extension list in `home/joshr/vscode.nix` for that reason — it hands the
shell's environment to language servers, terminals and the debugger. If
something still looks wrong, launching `code .` from inside a directory
direnv has already loaded is the quick way to tell the two apart.

`jnoortheen.nix-ide` is in the list too, pointed at the `nil` and `nixfmt`
from `development.nix` rather than downloading its own — so on a host with
that module still commented out, neither name resolves and both settings are
inert.

## Scheduled jobs

`server` runs its recurring work as **actual cronjobs**. The section is in
`hosts/server/configuration.nix`, and the option behind it is
`modules/nixos/cron.nix`:

```nix
local.cron = {
  enable = true;

  jobs = [
    {
      name = "nix-gc";
      description = "Trim the store beyond what base.nix's weekly GC keeps";
      schedule = "30 3 * * 0";
      command = "nix-collect-garbage --delete-older-than 30d";
    }
  ];
};
```

Each entry becomes one line of the system crontab plus a comment, so
`/etc/crontab` stays readable. `user` defaults to `root`. `schedule` is
standard five-field crontab syntax, and the `@daily` / `@weekly` / `@reboot`
shorthands work too. Schedules are in the system timezone (`time.timeZone`),
not UTC.

Three things worth knowing:

- **Bare command names work here**, which is the opposite of the usual cron
  advice. nixpkgs' cron module writes `SHELL=…/bash` and
  `PATH=<system.path>/bin:<system.path>/sbin` above our jobs, so anything in
  `environment.systemPackages` resolves by name. `local.cron.path` exists for
  tools that *aren't* installed system-wide, and it extends that PATH rather
  than replacing it — replacing it is the easy mistake, since a second `PATH=`
  line in a crontab wins over the first.
- **`%` is a crontab metacharacter**, meaning "newline" — everything after the
  first one is fed to the job on stdin. `date +%F` has to be written
  `date +\%F`.
- **A job missed while the machine was off never runs.** Cron has no catch-up.

### When not to use it

Cron was chosen because crontab syntax is familiar and these jobs are the
boring kind. It is genuinely the weaker tool: output goes to a mail spool that
no MTA is reading, so a job that's been failing for a month is invisible;
`systemctl list-timers` has no equivalent; and there's the missed-job problem
above.

So if a job *matters* — skipping it silently is a problem, or you'll want to
know why it failed three days ago — write it as a systemd service plus a timer
with `Persistent = true` directly in the host config. Nothing stops the two
coexisting. For output you actually want to read from a cron job, redirect it
yourself: `... 2>&1 | systemd-cat -t backup`.

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

# Pull a fresh wallhaven toplist. --refresh because Nix caches fetched files
# for an hour; without it you get the copy you already have. See "Wallpapers":
nix flake update --refresh wallhaven-toplist
```

`nix flake update` rewrites `flake.lock` — commit it alongside whatever
prompted the update, so a build that works is a build you can get back to.
If an update breaks something, `git checkout flake.lock` and rebuild.

If a rebuild leaves you with a broken desktop, pick the previous generation
from the systemd-boot menu at startup — nothing is destroyed by a bad switch.

## Hosts

Five are defined. Pick one with the flake attribute:

| Host | For | Differences |
|---|---|---|
| `gamestation` | the desk, Plasma | NVIDIA; second-monitor panel; kernel params |
| `laptop` | portable, Plasma | no NVIDIA; power management; single-display panels |
| `gamestation-niri` | the desk, niri | as above, niri + SDDM instead of Plasma |
| `laptop-niri` | portable, niri | as above; no OpenRGB applet at login |
| `server` | headless | no desktop at all; systemd-boot; cron jobs |

```bash
sudo nixos-rebuild switch --flake .#gamestation
sudo nixos-rebuild switch --flake .#laptop
sudo nixos-rebuild switch --flake .#server
```

The two desk hosts and the two laptop hosts share everything else — the same
modules, the same `home/joshr` profile, the same package set. `server` is the
outlier and is described below.

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

**Kernel command line.** `hosts/gamestation/kernel-params.nix` is imported by
both desk hosts — it's the same physical box, so the flags belong to the
hardware rather than to either session. It's a separate file because
`hardware-configuration.nix` is regenerated by `nixos-generate-config` and
says so at the top.

| | |
|---|---|
| `acpi_enforce_resources=lax` | lets i2c drivers touch ACPI-claimed regions, which is what OpenRGB needs to see SMBus RGB controllers — RAM and most motherboard headers. Without it OpenRGB finds the GPU and nothing else. It is a guard being switched off, not a feature switched on. |
| `nvidia_drm.fbdev=1` | gives the NVIDIA DRM driver a framebuffer console. `nvidia.nix` already sets the `modeset=1` half; this is the other, and it's what removes the flicker/black VT between bootloader and greeter. |
| `amd_iommu=on` + `iommu=pt` | AMD IOMMU on, in passthrough mode — identity-map the host's own devices so remapping is only paid for devices handed to a guest. Prerequisite for VFIO passthrough; does nothing on its own. |

**RGB.** The OpenRGB tray applet autostarts on the desk and **not** on the
laptop — `local.openrgb.autostart = false` in `home/joshr/laptop-niri.nix`.
The laptop has nothing for it to drive, so all it bought was a tray icon, a Qt
process and a failed profile load every session. The package is still
installed and the daemon still enabled, so launching it by hand for a docked
peripheral works.

### The server

`server` doesn't build on `home/joshr/home.nix`. That file is the *desktop*
base — kitty, VS Code, ranger, spicetify, Firefox, Discord, OBS, a cursor
theme, fonts pulled from the dotfiles repo — none of which a headless machine
uses and all of which it would still build. So `home/joshr/server.nix` is
shaped like `home/root/home.nix` instead: `home/common/shell.nix`, git, and
nothing else. Add to it directly rather than reaching for the desktop base.

It takes `base.nix`, `boot.nix`, `cron.nix` and `users.nix`, imports
`development.nix` for real rather than commented out, and pins
`local.boot.loader = "systemd-boot"` — there's no wallpaper to draw, and this
is the machine most likely to reboot unattended.

Get in over SSH. `base.nix` already enables sshd with password auth **off**,
so put a key in place before the first boot or the only way in is a physical
console. Tailscale is enabled there too and still needs `tailscale up` once.

Each host still needs its own hardware scan —
`hosts/laptop/hardware-configuration.nix` is the same placeholder as
gamestation's and must be regenerated on the machine.

### Adding another host

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
- the Firefox `userChrome.css` variable names in `theming.nix`, which are
  Firefox internals rather than API — a surface that comes out stock-coloured
  instead of themed means one of them was renamed, not that anything is
  broken. See "The browser".
- the VS Code theme extension. The mechanism is the same one home-manager's
  own `programs.vscode.…extensions` uses — a symlink under
  `~/.vscode/extensions` — so it should be picked up on the next start, but
  if `workbench.colorTheme = "Niri"` falls back to the default dark theme,
  `code --list-extensions` will say whether it was scanned.
- the emoji picker, on three counts. The font was inspected rather than
  rendered — its `name` table really does say `Fluent Emoji Color` and it
  really does carry CBDT, COLRv1 and OT-SVG tables, but nothing here ever drew
  a glyph with it, so if emoji come out as tofu boxes check `fc-match emoji`
  first. The typing half depends on `wtype`, which needs the virtual-keyboard
  protocol niri implements; if emoji land on the clipboard but never appear in
  the window, that's the half that failed, and the 150 ms pause in
  `emoji-type` is the number to raise. And wofi is being handed roughly 3,800
  rows, an order of magnitude more than the clipboard picker's 300 — it should
  be fine, but it was never timed.
- the OSD's stylesheet. The GTK4 node names and the two style-provider
  priorities were read off swayosd 0.3.1's own `style.scss` and `main.rs`, and
  the icon names off the gresource manifest it compiles into the binary, but
  nothing here ever drew the window. A pop-up in stock grey means the sheet
  didn't load — `systemctl --user status swayosd` prints "Loaded user defined
  CSS file" when it did, and a parse error when it didn't. `osd progress
  display-brightness-symbolic 50` draws one on demand without touching
  anything.
- limine's `uuid(…)` volume specifier, used for entries found on a disk other
  than the one NixOS boots from. Entries on this machine's own ESP use
  `boot():` and don't depend on it. `sudo systemctl start limine-theme-sync`
  and read `/boot/limine/limine.conf` to see what was written before you
  trust the menu.

## Updating the dotfiles-derived assets

```bash
nix flake update dotfiles   # pull in changes from joshrandall8478/dotfiles
```
