{ config, lib, pkgs, osConfig ? { }, niriTheming, niriScripts, niriClipboard, niriEmoji, ... }:

# niri's own config. There is no home-manager module for niri, so this is
# written out as a KDL file.
#
# Syntax was checked against niri 26.04's parser (niri-config/src/lib.rs) and
# its shipped default-config.kdl rather than from memory — KDL node and
# property names have moved between releases.
let
  inherit (niriTheming) activeDir;

  bin = pkg: lib.getExe pkg;

  # Per-host display layout, from local.niri.outputs. Empty on hosts that
  # don't set it, which leaves niri to auto-detect.
  renderOutput =
    o:
    let
      lines =
        lib.optional o.off "off"
        ++ lib.optional (o.mode != null) ''mode "${o.mode}"''
        ++ lib.optional (o.scale != null) "scale ${toString o.scale}"
        ++ lib.optional (o.transform != null) ''transform "${o.transform}"''
        ++ lib.optional (o.position != null)
          "position x=${toString o.position.x} y=${toString o.position.y}"
        ++ lib.optional o.variableRefreshRate "variable-refresh-rate"
        ++ lib.optional o.focusAtStartup "focus-at-startup";
    in
    ''
      output "${o.name}" {
      ${lib.concatMapStringsSep "\n" (l: "    ${l}") lines}
      }
    '';

  outputBlocks = lib.concatMapStringsSep "\n" renderOutput config.local.niri.outputs;

  workspaceNames = [ "1" "2" "3" "4" "5" ];

  workspaceBlocks = lib.concatMapStringsSep "\n" (
    n:
    if config.local.niri.workspaceOutput == null then
      ''workspace "${n}"''
    else
      ''
        workspace "${n}" {
            open-on-output "${config.local.niri.workspaceOutput}"
        }''
  ) workspaceNames;

  # The binds that address the shell rather than the compositor.
  #
  # Everything in this block is a command that exists in two versions: a
  # helper from ./scripts.nix driving one of the stack's daemons, or a line of
  # noctalia IPC. `shellBind` picks between them once so the keymap below can
  # stay a flat list of keys and not a list of conditionals.
  #
  # Only the binds that talk to the shell are here. Window management, the
  # workspace keys and the screenshot binds are the compositor's own actions
  # and are the same under both — as is Mod+Ctrl+T, which goes through
  # `theme-apply` either way (it is the switcher that knows how to tell each
  # shell; see scripts.nix).
  useNoctalia = config.local.niri.shell == "noctalia";

  # `pkgs.noctalia` and not `pkgs.noctalia-shell`: nixpkgs carries both majors
  # and the names read backwards. See the header of ./noctalia.nix.
  noctalia = lib.getExe pkgs.noctalia;
  shellBind = stack: ipc: if useNoctalia then "${noctalia} msg ${ipc}" else stack;

  terminal = "${pkgs.kitty}/bin/kitty";

  launcher = shellBind "${pkgs.wofi}/bin/wofi --show drun" "panel-toggle launcher";

  # noctalia has no separate emoji picker: emoji are a launcher provider,
  # reached by opening it pre-filled with that provider's trigger. So the key
  # still opens "the emoji picker" and there is one less program to keep a
  # database for — see ./emoji.nix for the bemoji one it replaces, which stays
  # installed and usable from a terminal.
  emojiPicker = shellBind (bin niriEmoji.emojiPicker) "panel-toggle launcher /emo";

  clipboardHistory = shellBind (bin niriClipboard.clipboardHistory) "panel-toggle clipboard";
  sessionMenu = shellBind (bin niriScripts.sessionMenu) "panel-toggle session";
  wallpaperMenu = shellBind (bin niriScripts.wallpaperMenu) "panel-toggle wallpaper";
  lockNow = shellBind (bin niriScripts.lockNow) "session lock";
  idleInhibit = shellBind "${bin niriScripts.idleInhibit} toggle" "caffeine-toggle";

  # Lock and blank in one key. `lock-blank` is a script under the stack
  # because it has to wait for swaylock to actually be up before powering the
  # outputs off; noctalia's lock is in-process, so the two IPC calls can just
  # be sequenced.
  lockBlank = shellBind (bin niriScripts.lockBlank) "session lock && ${noctalia} msg dpms-off";

  # Volume and brightness move wholesale, and the reason is the OSD rather
  # than the level.
  #
  # The `volume` and `brightness` helpers exist because niri has no OSD: each
  # makes its change and then calls swayosd-client to draw the result (see the
  # note on `osd` in ./scripts.nix). Under noctalia swayosd is not running, so
  # those helpers would still move the level and then draw nothing. noctalia
  # watches the devices itself and pops its own OSD for whatever moved them.
  #
  # Brightness in particular loses nothing by moving. The helper steps *every*
  # backlight device because plain brightnessctl moves only the first, which is
  # wrong on the desk where ddcci-backlight registers one device per monitor;
  # noctalia enumerates them all and `brightness-up` with no target steps the
  # focused monitor, which is the more useful answer to the same problem.
  #
  # The helpers are still built, still on PATH, and still what the idle dim
  # runs — `dim`/`restore` record the pre-dim level, which noctalia has no
  # equivalent for. See the `idle` block in ./noctalia.nix.
  volumeUp = shellBind "${bin niriScripts.volume} up" "volume-up";
  volumeDown = shellBind "${bin niriScripts.volume} down" "volume-down";
  volumeMute = shellBind "${bin niriScripts.volume} mute" "volume-mute";
  micMute = shellBind "${bin niriScripts.volume} mic-mute" "mic-mute";
  brightnessUp = shellBind "${bin niriScripts.brightness} up" "brightness-up";
  brightnessDown = shellBind "${bin niriScripts.brightness} down" "brightness-down";

  # Put back the wallpaper the picker last chose, at login.
  #
  # Only under the waybar stack. awww starts empty and `wallpaper-set` writes
  # the choice to a state file for this to read back; noctalia owns the
  # wallpaper and remembers the selection itself, so there is nothing to
  # restore and the spawn would be a second program fighting it for the
  # background. An empty string here leaves the line out of config.kdl.
  wallpaperRestoreSpawn = lib.optionalString (
    !useNoctalia
  ) ''spawn-at-startup "${bin niriScripts.wallpaperRestore}"'';

  # noctalia's `niri` template writes ~/.config/niri/noctalia.kdl and its hook
  # wants to add this line to config.kdl — which is a read-only store symlink
  # here, so the write would fail. Declaring the include means the hook's
  # `has_noctalia_include` check passes and it returns without touching the
  # file. See the templates note in ./noctalia.nix.
  #
  # **`optional=true` is load-bearing, and leaving it off broke everything.**
  # niri treats a missing include as a hard parse error — the tolerant branch
  # in its `include` handler is reached only when the node carries this
  # property (niri-config/src/lib.rs), and without it a `failed to read
  # included config` aborts the *whole* config, not just the themed part. That
  # is the state a session is in before noctalia has ever applied its
  # templates: the file is named here at build time and only written the first
  # time the shell renders a palette, so a fresh install, a new user, or a
  # `theme-apply` that has not happened yet all leave it absent.
  #
  # The hook's own `has_noctalia_include` regex allows trailing content after
  # the filename, so the property does not stop it recognising the line.
  #
  # Relative rather than absolute, which is safe despite config.kdl being a
  # symlink into the store: niri joins a relative include onto the parent of
  # the path it was *given* and never canonicalises it, so this resolves to
  # ~/.config/niri/noctalia.kdl rather than to somewhere in /nix/store.
  #
  # Deliberately *after* the theme include above. Both set the focus ring and
  # border colours and the later one wins; they are drawn from the same
  # palette either way, but a single rule about which is authoritative beats
  # two that happen to agree.
  noctaliaInclude = lib.optionalString useNoctalia ''include "noctalia.kdl" optional=true'';
  # finalPackage rather than pkgs.firefox: that's the wrapper home-manager
  # actually installs, carrying whatever ../firefox.nix declares beyond plain
  # prefs. Naming the raw package here would launch a second, unwrapped build.
  #browser = "${config.programs.firefox.finalPackage}/bin/firefox";
  browser = "${pkgs.vivaldi}/bin/vivaldi";
  fileManager = "${pkgs.kdePackages.dolphin}/bin/dolphin";
  # Bare `ranger` so it resolves from PATH to home-manager's wrapped build,
  # which carries the preview tools. The raw ${pkgs.ranger} has none of them.
  fileManagerTui = "${terminal} -e ranger";

  # OpenRGB's tray applet, applying the configured profile at login.
  #
  # Both halves of this come from the NixOS side through `osConfig` —
  # home-manager's handle on the system config, which exists because
  # home-manager is a NixOS module here (flake.nix). The `or` fallbacks are
  # for the case where it isn't; the options themselves are declared in
  # modules/nixos/options.nix, which every host reaches.
  #
  # `local.openrgb.autostart` follows `services.hardware.openrgb.enable`, so
  # this is a machine that has RGB hardware someone configured. On the laptop
  # it is off and this whole block is an empty string.
  #
  # `local.openrgb.profile` is shared with modules/nixos/openrgb.nix, which
  # re-applies the same profile after every resume. One name in one place: the
  # two disagreeing is the sort of bug nobody notices until a suspend.
  #
  # `--startminimized` is load-bearing twice over. OpenRGB drops to CLI mode
  # and *exits* as soon as it is given any option — `--profile` on its own
  # would apply the lighting and quit, leaving no tray icon — and this both
  # forces the GUI back on (it implies `--gui`) and keeps that GUI out of the
  # way. The resume service is the case that *wants* the CLI behaviour, and it
  # gets it by leaving this out.
  #
  # One string per argument, which is the detail this got wrong for a while.
  # `spawn-at-startup` is not a shell: niri execs the first string and hands it
  # the rest, so a whole command line in a single string is a program name with
  # spaces in it. That fails with ENOENT — silently, into niri's log — and the
  # login-time apply never happened at all. `spawn-sh-at-startup` is the node
  # that takes a command line; every other spawn in this file uses the
  # argument-per-string form, so this does too.
in
{
  xdg.configFile."niri/config.kdl".text = ''
    // Generated by home/joshr/niri/niri.nix — edit that, not this file.
    //
    // Colours live in the active theme, swapped by `theme-apply`. niri
    // reloads its config automatically when this include target changes.
    include "${activeDir}/niri.kdl"
    ${noctaliaInclude}

    // Displays. Set per host in home/joshr/<host>-niri.nix via
    // local.niri.outputs; nothing here means niri auto-detects.
    ${outputBlocks}

    input {
        keyboard {
            numlock
            xkb {
                layout "us"
            }
            repeat-delay 400
            repeat-rate 40
        }

        touchpad {
            tap
            natural-scroll
            dwt
            accel-profile "adaptive"
            scroll-method "two-finger"
        }

        mouse {
            // Flat profile: no pointer acceleration. Matches the setting
            // carried over from the Plasma config.
            accel-profile "flat"
        }

        // Focus follows the mouse only when it crosses into another window.
        focus-follows-mouse max-scroll-amount="0%"

        // Don't let a misbehaving client warp the cursor.
        warp-mouse-to-focus
    }

    layout {
        gaps 12

        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        default-column-width { proportion 0.5; }

        // waybar is a layer-shell panel, so niri already reserves space for
        // it; struts are only extra outer gaps on top of that.
        struts {
            top 0
            bottom 0
            left 0
            right 0
        }
        // Sets the fallback background fill color to solid black
        background-color "#303030"
    }

    // Named workspaces. waybar's niri/workspaces module shows these, and the
    // Mod+<n> binds below jump straight to them.
    //
    // Pinned to an output when local.niri.workspaceOutput is set. niri
    // otherwise creates a workspace on whichever output happens to be
    // focused, so without this the numbered workspaces scatter across
    // displays depending on where you were standing when you first used one.
${workspaceBlocks}

    prefer-no-csd

    // Filename stamp is month-day-year on a 12-hour clock, to match every
    // other clock in the session. That does cost chronological sort order in
    // a file manager — %m-%d-%Y sorts January of every year together — so if
    // you ever want that back, "%Y-%m-%d %H-%M-%S" is the string to restore
    // here and in the `screenshot` script in scripts.nix.
    screenshot-path "~/Pictures/Screenshots/Screenshot from %m-%d-%Y %I-%M-%S %p.png"

    hotkey-overlay {
        skip-at-startup
    }

    environment {
        // Hint toolkits toward Wayland backends.
        NIXOS_OZONE_WL "1"
        MOZ_ENABLE_WAYLAND "1"
        QT_QPA_PLATFORM "wayland;xcb"
        QT_WAYLAND_DISABLE_WINDOWDECORATION "1"
        SDL_VIDEODRIVER "wayland"
        _JAVA_AWT_WM_NONREPARENTING "1"
        // Set by niri itself for its own session; declared here so child
        // processes agree on it.
        XDG_CURRENT_DESKTOP "niri"
        XDG_SESSION_TYPE "wayland"
    }

    cursor {
        xcursor-theme "Bibata-Modern-Ice"
        xcursor-size 24
        hide-when-typing
    }

    // X11 apps (Steam, some games, older Electron) go through
    // xwayland-satellite. The NixOS module installs it; this starts it.
    xwayland-satellite {
        path "${bin pkgs.xwayland-satellite}"
    }

    animations {
        slowdown 0.7
    }

    overview {
        zoom 0.5
    }

    // Neither shell is started here. waybar and noctalia both run as systemd
    // user services — waybar so the theme switcher can restart it (waybar.nix),
    // noctalia so a config change restarts it on its own (noctalia.nix) —
    // and starting either here as well would give two bars.
    ${wallpaperRestoreSpawn}

    // nm-applet is deliberately not started. Its tray icon duplicates the
    // waybar `network` module, and that module's click already opens
    // nm-connection-editor, so the applet added an icon and nothing else.

    // Floating dialogs, pickers and popups.
    window-rule {
        match app-id=r#"^org\.keepassxc\.KeePassXC$"#
        match app-id=r#"^org\.gnome\.Calculator$"#
        match app-id=r#"^Bitwarden$"#
        match title="^Picture-in-Picture$"
        match title="^Open File$"
        match title="^Save File$"
        open-floating true
    }

    //kcalc float
    window-rule {
        match app-id="kcalc"
        open-floating true
    	default-column-width { fixed 400; }
    	default-window-height { fixed 550; }	
    }

    // Steam notification
    window-rule {
         match app-id="steam" title=r#"^notificationtoasts_\d+_desktop$"#
         default-floating-position x=10 y=10 relative-to="bottom-right"
         open-focused false
    }

    // File transfer window
    window-rule {
         match app-id="org.kde.dolphin" title="File Transfer"
         open-floating true
         default-floating-position x=16 y=16 relative-to="bottom-right"
         open-focused false
    }

    // qjackctl
    window-rule {
        match app-id="QjackCtl"
        open-floating true
    }	

    // Rounded corners everywhere, matching waybar and wofi.
    window-rule {
        geometry-corner-radius 8
        clip-to-geometry true
    }

    // Games and video players: no rounding, no shadow, and don't let the
    // screen blank on them.
    window-rule {
        match app-id=r#"^steam_app_"#
        match app-id=r#"^gamescope$"#
        match app-id=r#"^mpv$"#
        geometry-corner-radius 0
        clip-to-geometry false
        shadow { off; }
    }

    // Blank the lock screen's own surface out of screencasts.
    layer-rule {
        match namespace="^wofi$"
        shadow { on; }
    }

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        // --- launching -------------------------------------------------
        Mod+Return hotkey-overlay-title="Terminal" { spawn-sh "${terminal}"; }
        Mod+D      hotkey-overlay-title="Applications" { spawn-sh "${launcher}"; }
        Alt+Space  hotkey-overlay-title="Applications" { spawn-sh "${launcher}"; } 
        Mod+E      hotkey-overlay-title="Files" { spawn-sh "${fileManager}"; }
        Mod+Ctrl+E hotkey-overlay-title="Files (ranger)" { spawn-sh "${fileManagerTui}"; }
        Mod+B      hotkey-overlay-title="Browser" { spawn-sh "${browser}"; }

        // --- clipboard -------------------------------------------------
        // Mod+V and Mod+Shift+V are both window management already, so the
        // history lands on the third one in the V family rather than
        // somewhere unrelated. See clipboard.nix.
        Mod+Ctrl+V hotkey-overlay-title="Clipboard history" { spawn-sh "${clipboardHistory}"; }

        // --- emoji ------------------------------------------------------
        // Mod+. because that is what opens the emoji picker on Windows, and
        // that reflex is the whole reason it's here. It cost this key's old
        // binding, `expel-window-from-column`, which moved down to
        // Mod+Shift+Period among the sizing binds. See emoji.nix.
        Mod+Period hotkey-overlay-title="Emoji" { spawn-sh "${emojiPicker}"; }

        // --- session ---------------------------------------------------
        // Lock is Mod+L, matching the Windows/KDE reflex. That costs the
        // vim-key `Mod+L` for focus-column-right — Mod+Right, Mod+scroll and
        // Mod+End all still walk right, so only the h/j/k/l set loses its "l".
        //
        // `lock-now` rather than `lock-session`: it is the one entry point
        // every route to the lock goes through — this key, the bar's lock
        // button, the session menu, switch-user and swayidle — so a second
        // request while already locked is a no-op instead of a second locker.
        // See scripts.nix.
        Mod+L hotkey-overlay-title="Lock" { spawn-sh "${lockNow}"; }

        // Lock *and* turn the displays off, in one key.
        //
        // Mod+L then Mod+Escape does the same thing in two presses; this is
        // the "I'm walking away" version. Both lock with no grace period —
        // that is the default for every deliberate lock now, and only the
        // idle timer in lock.nix asks for one.
        //
        // Any input powers the monitors back on and lands on the lock screen,
        // the same as the 600s idle blank in lock.nix.
        Mod+Shift+L hotkey-overlay-title="Lock and blank" { spawn-sh "${lockBlank}"; }

        // Blank the monitors now, from the lock screen or from the desktop.
        // Any input wakes them; on the lock screen that leaves swaylock
        // exactly where it was, so this is a screen-off, not an unlock.
        //
        // Works while locked with no `allow-when-locked` on it, and that is
        // deliberate rather than an oversight. niri keeps a whitelist of
        // actions that survive the lock — quit, change-vt, suspend,
        // power-off-monitors, power-on-monitors, switch-layout — and lets
        // those through regardless (`allowed_when_locked` in src/input/mod.rs).
        // Setting the property here would in fact be a config *error*: niri
        // only accepts `allow-when-locked` on spawn binds. It's the same
        // whitelist that lets swayidle's 600s blank, and Mod+Shift+L's blank,
        // fire through the lock. The whitelist is checked in `do_action`, so
        // it covers `niri msg action power-off-monitors` over IPC too, not
        // only the keybind.
        //
        // Mod+Escape rather than bare Escape because niri intercepts a bound
        // key unconditionally — `should_intercept_key` matches binds before
        // it ever looks at the lock state, and only *then* is the action
        // dropped if the session is locked and the action isn't whitelisted.
        // So a bare `Escape` bind would swallow Escape in every application,
        // all the time: no dismissing a dialog, no leaving vim's insert mode,
        // no closing a wofi prompt. There is no "only while locked" bind
        // flag to scope it with — the full set is repeat, cooldown-ms,
        // allow-when-locked, allow-inhibiting and hotkey-overlay-title.
        Mod+Escape hotkey-overlay-title="Blank monitors" { power-off-monitors; }

        Mod+Shift+Escape hotkey-overlay-title="Session menu" { spawn-sh "${sessionMenu}"; }
        Ctrl+Alt+Delete hotkey-overlay-title="Session menu" { spawn-sh "${sessionMenu}"; }

        // Niri permits its built-in `quit` action through a session lock.
        // Spawn actions are blocked while locked unless they explicitly opt
        // into `allow-when-locked`, so route both quit shortcuts through IPC.
        Mod+Shift+E { spawn "${bin pkgs.niri}" "msg" "action" "quit"; } 

        // Hold the machine awake: no dim, no lock, no blank, no sleep, and on
        // the laptop no lid switch either, until it is toggled back off. The
        // same script the bar's coffee cup runs, so the key and the click
        // can't disagree — see idle-inhibit in scripts.nix and the unit it
        // drives in lock.nix.
        //
        // The title names the inhibitor as well as what it does, because the
        // hotkey overlay (Mod+Shift+/) is where you go looking for this key,
        // and "idle" is the word you would search it for.
        Mod+Shift+I hotkey-overlay-title="Stay awake — toggle idle inhibitor" { spawn-sh "${idleInhibit}"; }

        // --- theming ---------------------------------------------------
        // Pick a theme, or a wallpaper. Both deliberate, both on Mod+Ctrl.
        //
        // The Mod+Shift halves of these two pairs are gone. They jumped to a
        // *random* theme and a random wallpaper, which is a fine thing to
        // have on a keyboard exactly once and a bad thing to have next to the
        // pickers: Mod+Shift+W is one slip from Mod+Ctrl+W, and the slip
        // silently replaced whatever you had chosen. `theme-random`,
        // `theme-cycle` and `wallpaper-random` are all still on PATH for when
        // that is actually what you want.
        // Mod+Ctrl+T  hotkey-overlay-title="Choose theme" { spawn "${bin niriScripts.themeMenu}"; }
        Mod+Ctrl+W  hotkey-overlay-title="Choose wallpaper" { spawn-sh "${wallpaperMenu}"; }

        // --- screenshots -----------------------------------------------
        // Region capture goes through satty for annotation; the plain
        // screen/window captures use niri's own actions, which already know
        // the exact geometry.
        //
        // `last` re-shoots the region selected the time before, with no
        // slurp step — for taking the same frame repeatedly, where redrawing
        // the box by hand is both the tedious part and the reason successive
        // shots don't line up. It falls back to a selection if there's no
        // remembered region yet, or if that region has gone off-screen.
        Print              hotkey-overlay-title="Screenshot region" { spawn "${bin niriScripts.screenshot}"; }
        Shift+Print        hotkey-overlay-title="Screenshot last region" { spawn "${bin niriScripts.screenshot}" "last"; }
        Ctrl+Print         { screenshot-screen; }
        Alt+Print          { screenshot-window; }
        Mod+Shift+S        hotkey-overlay-title="Screenshot region" { spawn "${bin niriScripts.screenshot}"; }
        Mod+Ctrl+S         hotkey-overlay-title="Screenshot last region" { spawn "${bin niriScripts.screenshot}" "last"; }

        // --- media / hardware keys -------------------------------------
        // `volume` rather than wpctl directly, for the on-screen display: it
        // makes the same wpctl call these binds used to carry inline, then
        // reads the level back and hands it to swayosd. See scripts.nix and
        // osd.nix.
        //
        // The OSD is not visible on the lock screen — a session lock draws
        // above every layer-shell surface, which is the whole point of it —
        // but `allow-when-locked` still matters, because the volume itself
        // has to keep moving there.
        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "${volumeUp}"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "${volumeDown}"; }
        XF86AudioMute        allow-when-locked=true { spawn-sh "${volumeMute}"; }
        XF86AudioMicMute     allow-when-locked=true { spawn-sh "${micMute}"; }

        XF86AudioPlay allow-when-locked=true { spawn "${bin pkgs.playerctl}" "play-pause"; }
        XF86AudioStop allow-when-locked=true { spawn "${bin pkgs.playerctl}" "stop"; }
        XF86AudioPrev allow-when-locked=true { spawn "${bin pkgs.playerctl}" "previous"; }
        XF86AudioNext allow-when-locked=true { spawn "${bin pkgs.playerctl}" "next"; }

	// Launch calcultor
	XF86Calculator { spawn-sh "${pkgs.kdePackages.kcalc}/bin/kcalc"; }

        // `brightness` rather than brightnessctl directly: it steps *every*
        // backlight device, where brightnessctl on its own takes the first
        // one it finds. That's the same thing on the laptop's single internal
        // panel, but the desk has one device per monitor (see
        // modules/nixos/ddcci.nix) and only one of them would move. It also
        // draws the OSD afterwards, the same as `volume` above.
        XF86MonBrightnessUp   allow-when-locked=true { spawn-sh "${brightnessUp}"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn-sh "${brightnessDown}"; }

        // Power profile: power-saver, balanced, performance. Mod+P steps
        // forward through whatever the daemon offers and Mod+Ctrl+P steps
        // back — the same two directions as the bar's left and right click,
        // which is the other way to reach this.
        //
        // Ctrl rather than Shift for the reverse because Mod+Shift+P is
        // already a second way to blank the monitors, at the bottom of this
        // block.
        //
        // Neither one draws the pop-up. That is power-profile-osd, which
        // watches the daemon and therefore also catches the changes these keys
        // didn't make; see osd.nix.
        //
        // No `allow-when-locked`. Unlike volume and brightness there is nothing
        // to gain from moving it behind a lock screen, and the OSD wouldn't be
        // visible to confirm it either way.
        Mod+P      hotkey-overlay-title="Next power profile" { spawn "${bin niriScripts.powerProfile}" "next"; }
        Mod+Ctrl+P hotkey-overlay-title="Previous power profile" { spawn "${bin niriScripts.powerProfile}" "prev"; }

        // --- window management -----------------------------------------
        Mod+Q repeat=false { close-window; }
        Alt+F4 repeat=false { close-window; }
        Mod+O repeat=false { toggle-overview; }
        Mod+Tab repeat=false { toggle-overview; }

        Mod+Left  { focus-column-left; }
        Mod+Down  { focus-window-down; }
        Mod+Up    { focus-window-up; }
        Mod+Right { focus-column-right; }
        Mod+H     { focus-column-left; }
        Mod+J     { focus-window-down; }
        Mod+K     { focus-window-up; }
        // No Mod+L here — it locks the session (see the session binds above).

        Mod+Ctrl+Left  { move-column-left; }
        Mod+Ctrl+Down  { move-window-down; }
        Mod+Ctrl+Up    { move-window-up; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+H     { move-column-left; }
        Mod+Ctrl+J     { move-window-down; }
        Mod+Ctrl+K     { move-window-up; }
        Mod+Ctrl+L     { move-column-right; }

        Mod+Home { focus-column-first; }
        Mod+End  { focus-column-last; }

        // --- workspaces -------------------------------------------------
        Mod+Page_Down      { focus-workspace-down; }
        Mod+Page_Up        { focus-workspace-up; }
        Mod+U              { focus-workspace-down; }
        Mod+I              { focus-workspace-up; }
        Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
        Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }

        Mod+1 { focus-workspace "1"; }
        Mod+2 { focus-workspace "2"; }
        Mod+3 { focus-workspace "3"; }
        Mod+4 { focus-workspace "4"; }
        Mod+5 { focus-workspace "5"; }

        Mod+Shift+1 { move-column-to-workspace "1"; }
        Mod+Shift+2 { move-column-to-workspace "2"; }
        Mod+Shift+3 { move-column-to-workspace "3"; }
        Mod+Shift+4 { move-column-to-workspace "4"; }
        Mod+Shift+5 { move-column-to-workspace "5"; }

        // --- scrolling --------------------------------------------------
        // Mod + scroll moves along the row of windows. niri lays windows out
        // on one horizontal strip, so a vertical scroll mapping to
        // left/right is the natural gesture: spin the wheel and you travel
        // the strip.
        //
        // Wheel and touchpad are bound separately — they're distinct
        // triggers, so binding only WheelScroll* leaves the touchpad dead.
        // No cooldown here: unlike workspace switching, stepping several
        // windows in one flick is the point.
        Mod+WheelScrollDown    { focus-column-right; }
        Mod+WheelScrollUp      { focus-column-left; }
        Mod+WheelScrollRight   { focus-column-right; }
        Mod+WheelScrollLeft    { focus-column-left; }

        Mod+TouchpadScrollDown  { focus-column-right; }
        Mod+TouchpadScrollUp    { focus-column-left; }
        Mod+TouchpadScrollRight { focus-column-right; }
        Mod+TouchpadScrollLeft  { focus-column-left; }

        // Workspaces move to Mod+Shift+scroll, since Mod+scroll now walks
        // windows. Kept on a cooldown so one flick is one workspace.
        Mod+Shift+WheelScrollDown     cooldown-ms=150 { focus-workspace-down; }
        Mod+Shift+WheelScrollUp       cooldown-ms=150 { focus-workspace-up; }
        Mod+Shift+TouchpadScrollDown  cooldown-ms=150 { focus-workspace-down; }
        Mod+Shift+TouchpadScrollUp    cooldown-ms=150 { focus-workspace-up; }

        // Carry the focused column with you.
        Mod+Ctrl+WheelScrollDown    cooldown-ms=150 { move-column-to-workspace-down; }
        Mod+Ctrl+WheelScrollUp      cooldown-ms=150 { move-column-to-workspace-up; }
        Mod+Ctrl+TouchpadScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
        Mod+Ctrl+TouchpadScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

        // --- monitors ---------------------------------------------------
        Mod+Shift+Left  { focus-monitor-left; }
        Mod+Shift+Right { focus-monitor-right; }
        Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
        Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }

        // --- sizing -----------------------------------------------------
        Mod+R       { switch-preset-column-width; }
        Mod+Shift+R { switch-preset-window-height; }
        Mod+F       { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+M       { maximize-window-to-edges; }
        Mod+C       { center-column; }
        Mod+Minus   { set-column-width "-10%"; }
        Mod+Equal   { set-column-width "+10%"; }
        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }

        Mod+BracketLeft  { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }
        Mod+Comma  { consume-window-into-column; }
        // Expel is on Mod+Shift+Period rather than beside its Mod+Comma
        // partner, because Mod+Period is the emoji picker now. Nothing is
        // lost either way — Mod+BracketLeft/Right already consume and expel,
        // and they're the pair that reads as a direction.
        Mod+Shift+Period { expel-window-from-column; }

        Mod+V       { toggle-window-floating; }
        Mod+Shift+V { switch-focus-between-floating-and-tiling; }
        // Titled so it shows up in the Important Hotkeys overlay at all.
        // That page is niri's own hardcoded list of actions plus whatever
        // carries a hotkey-overlay-title, and tabbed display isn't on the
        // hardcoded list — float and float/tile focus just above it are,
        // which is why they need no title and this does.
        Mod+W hotkey-overlay-title="Tabbed column (toggle)" { toggle-column-tabbed-display; }

        Mod+Shift+P { power-off-monitors; }
    }
  '';

  # OpenRGB's own "Start At Login", switched back off.
  #
  # OpenRGB has a "Start At Login" checkbox of its own (Settings → General).
  # Ticking it writes ~/.config/autostart/OpenRGB.desktop — an ordinary XDG
  # autostart entry, carrying the same --startminimized/--profile arguments
  # the spawn above passes. niri's session runs those entries: niri.service
  # pulls in xdg-desktop-autostart.target, which is the same reason
  # networkmanagerapplet still appeared after its spawn was removed (see the
  # note in waybar.nix). So with that box ticked the applet starts twice —
  # once from this file, once from that entry.
  #
  # It is an easy box to have ticked. It is the only way to autostart the
  # applet in the Plasma session on this machine, and it was the only way that
  # worked in this one too for as long as the spawn above was packed into a
  # single string and died with ENOENT. Fixing the spawn is what turned one
  # applet into two; the entry had been carrying it alone until then.
  #
  # OpenRGB does nothing to stop the second instance: there is no singleton
  # lock, both processes start, and the first one to finish detection takes
  # the hardware. The second is left with an empty device list. The symptom is
  # therefore two tray icons, one of which controls nothing — not flickering
  # lighting, which is what you would expect if they were both driving it.
  #
  # Masked with a Hidden=true stub, which is the same trick ./default.nix uses
  # on blueman. `force` because the target is a file OpenRGB writes for
  # itself, and home-manager refuses to replace one of those unless told to.
  #
  # Gated on the same option as the spawn, so this only claims the file on the
  # hosts where this file is what starts the applet. On the laptop, and in the
  # Plasma session, an autostart entry is the user's own business.
  #
  # One consequence: OpenRGB's checkbox now reads "on" permanently, because it
  # decides by asking whether the file exists and it does — it just says
  # Hidden=true. Unticking it deletes the stub and the next home-manager
  # activation writes it back. Nothing starts twice either way, which is the
  # point.
  xdg.configFile."autostart/OpenRGB.desktop" =
    lib.mkIf (osConfig.local.openrgb.autostart or false) {
      force = true;
      text = ''
        [Desktop Entry]
        Type=Application
        Name=OpenRGB
        Hidden=true
      '';
    };
}
