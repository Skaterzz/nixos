{
  config,
  lib,
  pkgs,
  ...
}:

# GameMode for the session: the compositor and the shell, stripped back while a
# game is running.
#
# What this is for
# ----------------
# `programs.gamemode` in modules/nixos/gaming.nix already does the *system*
# half — governor, scheduler, the card's power profile, and taking video memory
# back off the model server. None of that touches the desktop drawing itself,
# and on this session the desktop draws quite a lot: niri runs a three-pass
# Kawase blur behind the bar every frame it is damaged, noctalia animates every
# widget and panel it owns and samples CPU, memory, network and — through NVML
# — the card itself on a timer, and both of them composite translucent surfaces
# over whatever is behind them. All of that is work the GPU is doing instead of
# the game.
#
# So this is a second mode with the same name, sitting on the session side of
# the line: animations off, blur off, transparency off, shadows off, sampling
# stopped. It is reached three ways, and they are the same mode each time —
# Mod+G, `niri-gamemode` from a terminal, and gamemoderun starting a game.
#
# How the two configs are changed without being rewritten
# -------------------------------------------------------
# Both config files this session runs on are read-only symlinks into the store,
# so nothing here can edit them. Both readers, fortunately, merge more than one
# file, and both notice a new one arriving:
#
#   niri      `include "gamemode.kdl" optional=true`, last line of config.kdl.
#             niri merges duplicate sections property by property in document
#             order and the later definition wins, so an include placed after
#             everything else is an override file. Its watcher polls the
#             *include* paths too — every 500ms, comparing mtime and the
#             canonical path — and records a missing one as absent rather than
#             skipping it, so the file appearing and the file being deleted are
#             both changes it reloads on. See ./niri.nix for the include line.
#
#   noctalia  every `*.toml` directly in ~/.config/noctalia is parsed and
#             deep-merged in sorted filename order (`mergeConfigWithIncludes`),
#             and `gamemode.toml` sorts after `config.toml`. Tables merge key
#             by key, so the overlay only has to name what it changes.
#
# That is why this is two generated files that get placed and removed rather
# than a script editing configuration in place: entering and leaving the mode
# is `mv` and `rm`, and nothing is ever half-written.
#
# The one asymmetry is the removal. noctalia's inotify mask is
# IN_MODIFY | IN_CLOSE_WRITE | IN_CREATE | IN_MOVED_TO — no IN_DELETE — so it
# never hears the overlay *go away*. `noctalia msg config-reload` is what
# closes that gap, and it is sent in both directions so the two paths are the
# same path.
let
  useNoctalia = config.local.niri.shell == "noctalia";

  # Stock `pkgs.noctalia`, not the patched build ./noctalia.nix may select.
  #
  # Same choice ./niri.nix already makes for its `noctalia msg` binds, and for
  # the same two reasons: `msg` is a client that talks to whatever is listening
  # on the socket rather than a second copy of the shell, and reaching for the
  # patched derivation from here would mean this file consuming an argument
  # ./noctalia.nix publishes while that file consumes one this publishes.
  noctalia = lib.getExe pkgs.noctalia;

  # --- state -------------------------------------------------------------
  #
  # The existence of `owner` is the mode, and its contents say who turned it
  # on: `manual` for the key, `game` for gamemoderun. That second word is the
  # whole reason this is a file rather than a test for the overlays, and it
  # buys one rule — **the end hook only turns off what the start hook turned
  # on**. Without it, playing a game would silently clear a mode that was set
  # by hand an hour earlier, and quitting the game would be the last place
  # anyone would look for why the desktop changed back.
  #
  # The three rules it produces, in full:
  #
  #   Mod+G          always toggles, and always takes the owner. It is the key
  #                  the mode is named after and it has to visibly work even
  #                  mid-game.
  #   game start     engages if nothing already has; leaves an existing owner
  #                  alone, so a manual hold is not downgraded.
  #   game end       disengages only when the owner is `game`.
  #
  # It is deliberately *not* under $XDG_RUNTIME_DIR, so the mode survives a
  # relogin. That is right for the key — you turned it on — and the cost is
  # that a machine which hard-locked mid-game comes back still in GameMode.
  # What makes that survivable is the bar: the GameMode pad is lit whenever
  # this file exists, so the state is never silently on. See ./noctalia.nix.
  stateDir = "${config.xdg.stateHome}/niri-gamemode";
  ownerFile = "${stateDir}/owner";

  niriOverlayPath = "${config.xdg.configHome}/niri/gamemode.kdl";
  noctaliaOverlayPath = "${config.xdg.configHome}/noctalia/gamemode.toml";

  # --- the niri overlay ---------------------------------------------------
  #
  # Two nodes, and the second one is the expensive half.
  #
  # `blur` is niri's own dual-Kawase blur — three passes by default — run over
  # whatever region a surface asks for through ext-background-effect-v1.
  # noctalia asks for one covering the entire bar (`applyBarCompositorBlur`),
  # unconditionally and regardless of how opaque the bar is, so the bar is
  # blurred on this session whenever it is on screen and being redrawn. Turning
  # transparency off in the overlay below does not stop that; only this does.
  #
  # `animations` is the cheaper one and the more visible: it stops niri
  # animating window opens, closes, resizes, workspace switches and the
  # overview, which is a GPU cost per transition and a delay before the frame
  # you actually asked for. config.kdl sets `slowdown 0.7`; `off` here replaces
  # it, and niri's own merge is what makes a later file win.
  niriOverlay = pkgs.writeText "niri-gamemode.kdl" ''
    // Placed by `niri-gamemode`, removed when GameMode ends. Not a file to
    // edit — home/joshr/niri/gamemode.nix generates it, and the next toggle
    // overwrites whatever is here.
    //
    // config.kdl includes this last on purpose: niri merges duplicate sections
    // property by property in document order, so what this sets replaces what
    // the same nodes set earlier and leaves everything else alone.

    animations {
        off;
    }

    blur {
        off;
    }
  '';

  # --- the noctalia overlay -----------------------------------------------
  #
  # Only the keys that change, because a deep merge means the rest of
  # config.toml is still there underneath. Grouped by what each one costs:
  #
  #   shell.animation      every widget, panel, OSD and toast noctalia draws
  #                        runs through one motion service; `enabled = false`
  #                        makes it deliver the end state immediately instead
  #                        of interpolating to it.
  #   *.background_opacity a translucent surface is a surface the compositor
  #                        has to blend against what is behind it rather than
  #                        overwrite. Fully opaque is the cheap case, and on
  #                        the bar it is also what makes the missing blur look
  #                        deliberate rather than broken.
  #   panel.transparency_mode
  #                        the same thing one level in: "solid" stops the
  #                        in-panel cards being drawn translucent over the
  #                        panel they sit on.
  #   *.shadow             a shadow here is a second copy of the surface's
  #                        shape rendered with a large SDF softness — the bar's
  #                        is redrawn with the bar.
  #   system.monitor       the one that is not about drawing at all. Its
  #                        sampling thread reads /proc every two seconds and
  #                        dlopen's libnvidia-ml to ask the card for its
  #                        temperature and VRAM every five, which is a
  #                        second NVML client on the card the game is using.
  #                        `enabled = false` joins that thread and releases the
  #                        GPU readers rather than merely hiding the numbers.
  #
  # What is deliberately *not* here is the bar's audio visualiser, which is the
  # single most animated thing in the session. Widget lanes are TOML arrays and
  # a deep merge replaces an array wholesale, so dropping one entry means
  # restating the whole `bar.main.end` list — and the copy that lives here
  # would then drift from the one in ./noctalia.nix, which is the only file
  # that should be describing the bar. `local.waybar.cavaInBar` is the switch
  # for it, and it is off on the hosts that play games.
  #
  # The opacities are written `1` rather than `1.0` because that is what
  # actually lands: `pkgs.formats.toml` goes through `builtins.toJSON`, which
  # renders a whole-numbered Nix float as an integer, and json2toml has nothing
  # left to tell it otherwise. noctalia reads every float field through
  # `finiteDouble`, which takes a TOML int or float alike, so an integer is the
  # honest spelling of what the file will contain rather than a mistake.
  noctaliaOverlay = (pkgs.formats.toml { }).generate "noctalia-gamemode.toml" {
    shell = {
      animation.enabled = false;
      panel = {
        transparency_mode = "solid";
        shadow = false;
      };
    };

    bar.main = {
      background_opacity = 1;
      shadow = false;
    };

    notification.background_opacity = 1;
    osd.background_opacity = 1;

    system.monitor.enabled = false;
  };

  # Same build-time check ./noctalia.nix runs over config.toml, for the same
  # reason: a key noctalia has renamed upstream should fail the build naming
  # the line, not become an overlay that quietly stops applying. `validate`
  # takes a single file and checks it against the schema, so a partial one is
  # fine — that is exactly what this is.
  validatedNoctaliaOverlay = pkgs.runCommand "noctalia-gamemode.toml" { } ''
    ${noctalia} config validate ${noctaliaOverlay}
    cp ${noctaliaOverlay} $out
  '';

  # --- the mode itself ----------------------------------------------------
  #
  # Also the one place that knows how to ask gamemoded anything. That used to
  # be `gamemode-status` in ./scripts.nix, which the bar polled directly; the
  # dependency is now the other way round, and the reason is the poll interval.
  # The noctalia plugin ticks every two seconds and needs the finer answer, so
  # it should be the one paying for a single process; waybar wants a glyph and
  # ticks every thirty, so it can afford the extra hop.
  niriGamemode = pkgs.writeShellApplication {
    name = "niri-gamemode";
    runtimeInputs = with pkgs; [
      coreutils
      gamemode
      libnotify
      procps
    ];
    text = ''
      owner=${lib.escapeShellArg ownerFile}

      # Place a generated file where a config reader will find it, atomically.
      #
      # Both readers are woken by the write: noctalia watches the config
      # directory with inotify and niri stats the include path twice a second,
      # so a file that is still being copied can be parsed as a truncated one.
      # Neither `.tmp` name is picked up in the meantime — noctalia filters on
      # a `.toml` extension and niri only looks at the exact include path.
      place() {
        install -Dm644 "$1" "$2.tmp"
        mv -f "$2.tmp" "$2"
      }

      # Ask noctalia to re-read its config directory.
      #
      # Load-bearing on the way *out* and merely tidy on the way in: the
      # inotify mask noctalia sets carries IN_CREATE and IN_MOVED_TO but not
      # IN_DELETE, so it hears the overlay arrive and never hears it leave.
      # Sent in both directions anyway, so there is one code path rather than
      # two and so a session whose watch failed to register still tracks.
      #
      # `|| true` for every session that is not a running noctalia: the waybar
      # stack, a shell that has crashed, a run over ssh.
      reload() {
        ${lib.optionalString useNoctalia ''${noctalia} msg config-reload >/dev/null 2>&1 || true''}

        # And the bar under the other shell, which polls `gamemode-status` on
        # a 30-second interval and re-runs it on SIGRTMIN+9. Same number the
        # gamemode hooks in modules/nixos/gaming.nix send, and nothing checks
        # that the two agree.
        pkill -RTMIN+9 waybar || true
      }

      engage() {
        mkdir -p ${lib.escapeShellArg stateDir}
        place ${niriOverlay} ${lib.escapeShellArg niriOverlayPath}
        ${lib.optionalString useNoctalia
          "place ${validatedNoctaliaOverlay} ${lib.escapeShellArg noctaliaOverlayPath}"
        }

        # The state file last: it is what everything else reads as "the mode is
        # on", so it should not be true before the overlays it describes are in
        # place.
        printf '%s\n' "$1" > "$owner.tmp"
        mv -f "$owner.tmp" "$owner"

        reload
      }

      disengage() {
        # The state file first, for the reverse of the reason above.
        rm -f "$owner"

        # The noctalia overlay is removed even under the waybar stack, where
        # nothing ever writes it: a session that was switched between shells
        # while the mode was on should not leave a file behind that the next
        # switch back would silently pick up.
        rm -f ${lib.escapeShellArg niriOverlayPath} ${lib.escapeShellArg noctaliaOverlayPath}
        reload
      }

      # Is a game holding gamemode right now.
      #
      # There is nothing to ask when the daemon is down, and asking would
      # *start* it: gamemoded is D-Bus activated, so `gamemoded --status`
      # would launch the very thing it is supposed to be reporting on, every
      # time the bar ticks.
      #
      # pgrep rather than `systemctl --user is-active gamemoded.service`
      # because that hard-codes a unit name this config never sets. If the
      # name were ever wrong the check would fail exactly like "gamemode is
      # off" — silence that looks correct — where a wrong process name at
      # least fails the same way for everyone and shows up the first time a
      # game runs.
      daemon_active() {
        pgrep -x -u "$UID" gamemoded >/dev/null || return 1

        # "gamemode is inactive", "gamemode is active", or "gamemode is active
        # and [pid] registered". Matching `is active` rather than `active` is
        # the whole trick — "inactive" contains "active".
        case "$(gamemoded --status 2>/dev/null || true)" in
          *"is active"*) return 0 ;;
          *)             return 1 ;;
        esac
      }

      # One word: `game`, `manual`, `daemon` or `off`.
      #
      # The first two are this mode, named by who turned it on. `daemon` is the
      # fourth state and the reason there is a fourth: a game holding gamemode
      # while the *session* mode is off. It is reachable two ways — a Mod+G
      # pressed mid-game, and a `systemctl --user start` from the hook that
      # never landed — and in both of them the bar should still say a game is
      # running, because that is what the pad has always meant and the
      # system-level half of gamemode really is engaged. Folding it in with
      # `game` would have the tooltip claim the session is stripped back when
      # it is not.
      #
      # The state file is read first, so the daemon is only asked once there is
      # no answer here — which is also what keeps the two-second poll from
      # running pgrep at all while the mode is on.
      state() {
        if [ -e "$owner" ]; then
          case "$(cat "$owner" 2>/dev/null || true)" in
            game) echo game ;;
            *)    echo manual ;;
          esac
        elif daemon_active; then
          echo daemon
        else
          echo off
        fi
      }

      notify() {
        notify-send -a niri-gamemode -i input-gamepad "$1" "$2" || true
      }

      case "''${1:-toggle}" in
        # The key, and the only entry point that decides for itself. It reads
        # the state file rather than `state` above so that it is toggling the
        # thing it can actually change: with a game holding gamemode and the
        # session mode somehow off, "toggle" should turn the session mode on,
        # not report that something is already active and do nothing.
        toggle)
          if [ -e "$owner" ]; then
            disengage
            notify 'GameMode off' 'Animations, blur and transparency are back'
          else
            engage manual
            notify 'GameMode on' 'Animations, blur, transparency and system monitoring off'
          fi
          ;;

        on)
          engage manual
          notify 'GameMode on' 'Animations, blur, transparency and system monitoring off'
          ;;

        off)
          disengage
          notify 'GameMode off' 'Animations, blur and transparency are back'
          ;;

        # The gamemoderun halves, reached through the two user units below.
        #
        # Silent, both of them: modules/nixos/gaming.nix already raises
        # "GameMode started" and "GameMode ended" for the same event, and a
        # second toast saying the same thing in different words is noise at
        # exactly the moment a game is taking the screen.
        game-start)
          # Nothing to do if the mode is already on, and specifically nothing
          # to do to the owner — a manual hold stays manual, so quitting the
          # game leaves it where it was.
          if [ ! -e "$owner" ]; then
            engage game
          fi
          ;;

        game-end)
          if [ "$(cat "$owner" 2>/dev/null || true)" = "game" ]; then
            disengage
          fi
          ;;

        # One word, for the bar plugin in ./noctalia.nix.
        status)
          state
          ;;

        *)
          echo "usage: niri-gamemode [toggle|on|off|game-start|game-end|status]" >&2
          echo "  status prints one of: game manual daemon off" >&2
          exit 2
          ;;
      esac
    '';
  };

  # --- the same answer, as a bar glyph ------------------------------------
  #
  # What waybar's `custom/gamemode` module runs, and what it has always run.
  # All that changed is where the answer comes from: it is the mode above
  # rather than the daemon alone, so a Mod+G with nothing running lights the
  # pad exactly as a game does.
  #
  # Empty output rather than a dimmed glyph: waybar hides a custom module with
  # no text, so a mode that is off nearly always costs nothing while it is.
  # The noctalia plugin does not use this — it wants the four-state word, not
  # a glyph, and calls `niri-gamemode status` itself.
  gamemodeStatus = pkgs.writeShellApplication {
    name = "gamemode-status";
    runtimeInputs = [ niriGamemode ];
    text = ''
      case "$(niri-gamemode status)" in
        off) echo ;;
        *)   printf '%s\n' '󰊗' ;;
      esac
    '';
  };
in
{
  home.packages = [
    niriGamemode
    gamemodeStatus
  ];

  # --- how gamemoderun reaches a session script ---------------------------
  #
  # gamemode's `custom.start` and `custom.end` are set in
  # modules/nixos/gaming.nix, which is a NixOS module and therefore cannot
  # name a store path home-manager built. It also cannot find one by name:
  # gamemoded's own PATH is nearly empty, which is why every command in those
  # hooks is written as an absolute store path.
  #
  # These two units are the way across. gamemoded runs under the user's own
  # systemd manager — it is D-Bus activated on the session bus, which is also
  # why the existing hooks can call `notify-send` at all — so a hook can always
  # reach `systemctl --user`, and $XDG_RUNTIME_DIR is set for it by definition.
  # The system side then needs to know one unit name and nothing else, and on a
  # host or an account with no niri session the unit simply does not exist and
  # `systemctl --user start` fails into the `|| true` the hooks already carry
  # for `pkill`.
  #
  # The names are the interface: `niri-gamemode-start` and `niri-gamemode-stop`
  # are spelled out in modules/nixos/gaming.nix and nothing checks that the two
  # spellings agree — the same standing arrangement as SIGRTMIN+9 next door.
  #
  # No `Install.WantedBy`: neither is ever wanted at login, only started on
  # demand. `oneshot` so `systemctl start` is a request to run it once rather
  # than a service to supervise.
  systemd.user.services = {
    niri-gamemode-start = {
      Unit.Description = "Enter the session's GameMode (a game took gamemode)";
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe niriGamemode} game-start";
      };
    };

    niri-gamemode-stop = {
      Unit.Description = "Leave the session's GameMode (the game released gamemode)";
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe niriGamemode} game-end";
      };
    };
  };

  # Consumed by ./niri.nix for the Mod+G bind, ./noctalia.nix for the bar
  # plugin's poll, and ./waybar.nix for the custom/gamemode module.
  _module.args.niriGamemode = {
    inherit niriGamemode gamemodeStatus;
  };
}
