{ config, lib, pkgs, ... }:

let
  # ollama's HTTP API, if this host runs one. Both of these are read rather
  # than set — modules/nixos/ai.nix owns the service, this file only wants to
  # know whether there is one and where it listens.
  ollamaHere = config.services.ollama.enable;
  ollamaUrl = "http://127.0.0.1:${toString config.services.ollama.port}";

  # Whether the start hook has a model server to take the card back from. Both
  # halves have to be true — a host with no ollama has nothing to release, and
  # the option is the "my game may interrupt my agent" preference.
  releaseOnGameMode = ollamaHere && config.local.gaming.releaseGpuOnGameMode;

  # Take the card back from the model server when a game starts.
  #
  # ollama keeps a model in video memory for five minutes after the last
  # request (OLLAMA_KEEP_ALIVE), which is the right default for a machine
  # answering questions and the wrong one for a machine also being played on:
  # deepseek-r1:14b is around nine gigabytes that nobody is using by the time
  # the game wants them. Worse, nothing here is user-driven — Open WebUI in a
  # background tab, or the OpenClaw gateway (which lingers, so it is up with
  # nobody logged in) can load a model *while* a game is running, which is
  # what turns this into "the machine gets slower the longer I play" rather
  # than "the machine is slow".
  #
  # `keep_alive: 0` on /api/generate is ollama's documented way to say "drop
  # this now" — no CLI, no privileges, one loopback request per resident
  # model. There is no end hook to match: ollama loads on demand, so the next
  # question reloads whatever it needs by itself.
  #
  # **Stdout is a notification body.** Nothing is printed unless a model was
  # actually holding the card, and what is printed is meant to be read by
  # somebody who was about to play a game rather than by whoever is reading
  # the journal later — the model's name, and how much of the card it had.
  # gamemodeStart below is what puts it on screen.
  releaseGpu = pkgs.writeShellApplication {
    name = "gamemode-release-gpu";

    runtimeInputs = with pkgs; [
      curl
      jq
    ];

    text = ''
      # A server that isn't running, isn't up yet, or has nothing resident is
      # the ordinary case, not a failure — gamemoded logs a non-zero script,
      # and `-s` without `-S` keeps "connection refused" out of its journal
      # too. The unload below keeps `-S`, where a failure is worth reading.
      snapshot=$(curl -fs --max-time 2 "${ollamaUrl}/api/ps") || exit 0

      # name<TAB>GiB, one resident model per line, read once and reused: the
      # sizes have to be taken *before* the unloads, because after them
      # /api/ps has nothing left to report. A tenth of a gigabyte is as
      # precise as this needs to be — the number is here to say how much of
      # the card was gone, not to be audited.
      #
      # `|| exit 0` on the whole thing for the same reason the request above
      # has it: a server that answered with something this doesn't
      # understand is a hook that has nothing to do, not a hook that failed.
      # jq's complaint still reaches the journal.
      resident=$(printf '%s' "$snapshot" | jq -r '
        (.models // [])[] | "\(.name)\t\(.size_vram / 1073741824 * 10 | round / 10)"') || exit 0
      [ -n "$resident" ] || exit 0

      while IFS=$'\t' read -r model gib; do
        [ -n "$model" ] || continue
        # `if` rather than `|| true`: a model that would not unload is the
        # one case worth saying out loud, because it means the game is
        # starting on a card that is still part full and the frame rate is
        # about to be explained by something this hook already knows.
        if curl -fsS --max-time 10 "${ollamaUrl}/api/generate" \
          --json "{\"model\": \"$model\", \"prompt\": \"\", \"keep_alive\": 0}" \
          >/dev/null; then
          echo "released $model ($gib GiB)"
        else
          echo "$model ($gib GiB) would not unload"
        fi
      done <<< "$resident"
    '';
  };

  # Ask the niri session to enter or leave its own GameMode.
  #
  # That mode lives entirely on the home-manager side —
  # home/joshr/niri/gamemode.nix — because what it changes is the compositor's
  # and the shell's configuration: animations, blur, transparency, and the
  # shell's own CPU/GPU sampling. This module cannot name the script that does
  # it. A NixOS module has no handle on a store path home-manager built, and it
  # could not find one by name either: gamemoded's PATH is nearly empty, which
  # is why every other command in these hooks is written as an absolute store
  # path.
  #
  # A unit name crosses that gap where a path cannot. gamemoded runs under the
  # user's own systemd manager — it is D-Bus activated on the session bus,
  # which is also why `notify-send` above works at all — so `systemctl --user`
  # is always reachable from a hook and $XDG_RUNTIME_DIR is set for it by
  # definition. home-manager declares `niri-gamemode-start.service` and
  # `niri-gamemode-stop.service`; this only has to know those two names, and
  # nothing checks that the two files spell them the same way, exactly as
  # nothing checks SIGRTMIN+9 above.
  #
  # `--no-block` because gamemoded kills a custom script after ten seconds
  # (`script_timeout`) and there is nothing here worth waiting for. `|| true`
  # for every session that has no such unit: a Plasma login, root, an account
  # without the niri profile — the same shape as the `pkill` beside it.
  sessionGamemode =
    which:
    "${pkgs.systemd}/bin/systemctl --user start --no-block niri-gamemode-${which}.service || true";

  # What gamemode's start hook runs on a host that has a model server to take
  # the card back from. Everywhere else the hook stays the line of shell it
  # has always been — see `custom.start` below.
  #
  # It became a program when the notification had to start saying what the
  # release did, because that answer only exists once the release has run and
  # the notification cannot wait for it. Hence the order here, which is the
  # whole reason the file exists:
  #
  #   * The notification and the bar poke go first. They are the confirmation
  #     that the mode engaged, and they must not sit behind a model server
  #     that is mid-generation. gamemoded gives a custom script ten seconds
  #     and then kills it (`script_timeout`), so a release that hangs would
  #     otherwise take "GameMode started" down with it.
  #
  #   * The release then *rewrites* that notification rather than raising a
  #     second one behind it. `notify-send -p` prints the id the notification
  #     daemon assigned and `-r` replaces that id, so what the player sees is
  #     one notification that gains a line naming what was on the card once
  #     the card is back.
  gamemodeStart = pkgs.writeShellApplication {
    name = "gamemode-start-hook";

    runtimeInputs = with pkgs; [
      libnotify
      procps # pkill
      releaseGpu
    ];

    text = ''
      # A daemon that doesn't hand back an id, or no daemon at all, leaves
      # this empty and the rewrite below falls back to a plain notification.
      id=$(notify-send -p -i input-gamepad 'GameMode started') || id=""

      # waybar's custom/gamemode module is otherwise on a 30-second poll, and
      # a mode you turn on for a game should show up in the bar as the game
      # starts rather than up to half a minute later. SIGRTMIN+9 is the
      # `signal` that module is given in home/joshr/niri/waybar.nix — the two
      # numbers have to agree, and nothing checks that they do.
      #
      # `|| true` because pkill exits 1 when nothing matches, which is the
      # ordinary case in a Plasma session with no waybar running.
      pkill -RTMIN+9 waybar || true

      # And the session's own GameMode, on the same reasoning: it is the
      # confirmation that the mode engaged, so it goes before the release
      # rather than behind it. `systemctl` is spelled absolutely by
      # `sessionGamemode` above — see there for why this is a unit name and
      # not a command — so it needs no runtimeInput of its own.
      ${sessionGamemode "start"}

      # Silent when the card was already the game's: gamemode-release-gpu
      # prints nothing unless something was holding video memory, so an
      # ordinary launch notifies exactly as it did before this existed.
      freed=$(gamemode-release-gpu) || freed=""
      if [ -n "$freed" ]; then
        if [ -n "$id" ]; then
          notify-send -r "$id" -i input-gamepad 'GameMode started' "$freed" || true
        else
          notify-send -i input-gamepad 'GameMode started' "$freed" || true
        fi
      fi
    '';
  };

  # One command that answers "why is it slow *now*".
  #
  # The failure modes behind a game that degrades mid-session look identical
  # from the chair — frames drop, the hitching starts — and are told apart
  # only by numbers taken while it is happening. This prints all of them in
  # one go, so a bad session produces evidence instead of a memory:
  #
  #   * video memory near the card's total, or another process holding a
  #     chunk of it, means eviction to system memory. The NVIDIA driver does
  #     not degrade gracefully past that point.
  #   * a graphics clock far below its maximum with a reason listed under
  #     "Clocks Event Reasons" means thermal or power throttling, which is a
  #     case-and-fans answer rather than a configuration one.
  #   * a `~/.cache/nv` sitting near 1 GB with SKIP_CLEANUP unset means the
  #     driver is about to throw the shader cache away — see the long note in
  #     modules/nixos/nvidia.nix.
  #   * an empty EGL external platform directory means the XWayland path has
  #     fallen off its fast route, which is the regression in
  #     nixpkgs#524342 and the sway thread it links to.
  #
  # Every probe here is allowed to find nothing: no card, no model server, no
  # niri session. writeShellApplication runs this under `set -e`, so each one
  # ends in `|| true` — a diagnostic that stops at the first absent thing is
  # worse than no diagnostic.
  gamingDoctor = pkgs.writeShellApplication {
    name = "gaming-doctor";

    runtimeInputs =
      with pkgs;
      [
        coreutils
        curl
        gamemode # gamemoded --status
        gnugrep
        jq
        libnotify # the one finding worth leaving the terminal for
        procps # free, pgrep
        util-linux # swapon
      ]
      # nvidia-smi lives in the driver's `bin` output. Conditional because
      # this module has no NVIDIA dependency of its own — a host that imports
      # it with an AMD card gets a report with the card sections empty rather
      # than a build that pulls in a driver it will never load.
      ++ lib.optional (lib.elem "nvidia" config.services.xserver.videoDrivers) config.hardware.nvidia.package.bin
      ++ lib.optional config.services.power-profiles-daemon.enable pkgs.power-profiles-daemon;

    text = ''
      have() { command -v "$1" >/dev/null 2>&1; }
      section() { printf '\n== %s ==\n' "$1"; }

      echo "gaming-doctor on $(uname -n) at $(date '+%F %T')"
      echo "Run this *while* it is slow — most of what follows is a snapshot."

      section "driver"
      # One line, and it says both the version and whether this is the open
      # kernel module: the open one calls itself so in this string.
      cat /proc/driver/nvidia/version 2>/dev/null || echo "no NVIDIA driver loaded"
      grep -E 'PreserveVideoMemoryAllocations|EnableGpuFirmware|UseKernelSuspendNotifiers' \
        /proc/driver/nvidia/params 2>/dev/null || true

      section "the card, right now"
      if have nvidia-smi; then
        nvidia-smi --format=csv \
          --query-gpu=memory.used,memory.total,utilization.gpu,temperature.gpu,power.draw,power.limit,clocks.current.graphics,clocks.max.graphics,clocks.current.memory,clocks.max.memory \
          || true
      else
        echo "no nvidia-smi on PATH"
      fi

      section "throttling"
      # The authoritative answer. "Active" against anything other than
      # GpuIdle is the card telling you it is being held back, and by what.
      if have nvidia-smi; then
        nvidia-smi -q -d PERFORMANCE || true
      fi

      section "what is holding video memory"
      # Type G is a graphics client (the game, the compositor, a browser),
      # type C is compute (ollama, anything CUDA). Both come out of the same
      # pool.
      if have nvidia-smi; then
        nvidia-smi || true
      fi

      section "local model server"
      resident=$(curl -fsS --max-time 2 "${ollamaUrl}/api/ps" 2>/dev/null) || resident=""
      if [ -z "$resident" ]; then
        echo "nothing answering on ${ollamaUrl} — expected when local.ai is off"
      else
        count=$(echo "$resident" | jq -r '(.models // []) | length') || count=0
        echo "models resident: $count"
        echo "$resident" \
          | jq -r '(.models // [])[] | "  \(.name)  \(.size_vram / 1073741824 * 100 | round / 100) GiB VRAM, expires \(.expires_at)"' \
          || true

        # The one section that gets a notification of its own.
        #
        # Everything else here is a number to read in the terminal this was
        # typed into. A model resident on the card is different in kind: it
        # is the finding that explains a bad session, it is the one with
        # something to do about it (start a game and gamemode's hook takes
        # the card back, or `ollama stop <model>` by hand), and this is a
        # command as likely to be bound to a key and hit mid-game — with the
        # terminal behind a fullscreen window — as it is to be typed at a
        # prompt. Only when something is actually resident: a doctor that
        # notifies on a clean bill is noise.
        #
        # dialog-warning rather than the gamepad the gamemode hooks use,
        # because this is a finding rather than a change of state.
        #
        # `|| true` for the run with no session bus behind it: over ssh, or
        # from a unit, notify-send fails and that is not a failed report.
        if [ "$count" -gt 0 ]; then
          notify-send -i dialog-warning 'gaming-doctor: AI is holding the card' \
            "$(echo "$resident" \
              | jq -r '(.models // [])[] | "\(.name) — \(.size_vram / 1073741824 * 10 | round / 10) GiB VRAM"')" \
            || true
        fi
      fi

      section "shader cache"
      echo "__GL_SHADER_DISK_CACHE=''${__GL_SHADER_DISK_CACHE-unset}"
      echo "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=''${__GL_SHADER_DISK_CACHE_SKIP_CLEANUP-unset}"
      du -sh "''${XDG_CACHE_HOME:-$HOME/.cache}/nv" 2>/dev/null \
        || echo "no shader cache directory yet"

      section "EGL external platforms"
      # Without these JSON files NVIDIA's EGL has no Wayland or X11 external
      # platform to load, and XWayland clients — which is every Proton game —
      # fall back to a path that runs at a fraction of the speed. nixpkgs
      # installs them from egl-wayland, egl-gbm, egl-wayland2 and egl-x11, so
      # an empty listing here is the bug, not a quirk.
      ls -1 /run/opengl-driver/share/egl/egl_external_platform.d/ 2>/dev/null \
        || echo "EMPTY — see 'Gaming performance' in MANUAL.md"
      echo "__EGL_EXTERNAL_PLATFORM_CONFIG_DIRS=''${__EGL_EXTERNAL_PLATFORM_CONFIG_DIRS-unset}"

      section "system memory"
      free -h || true
      swapon --show || true

      section "cpu and power"
      cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
      if have powerprofilesctl; then powerprofilesctl get || true; fi
      # gamemoded is D-Bus activated, so asking it for its status is enough to
      # start it — check it is already up first, the same way the bar's
      # gamemode indicator does (gamemodeStatus in
      # home/joshr/niri/gamemode.nix).
      if pgrep -x gamemoded >/dev/null 2>&1; then
        gamemoded --status || true
      else
        echo "gamemoded not running (no game holds gamemode)"
      fi

      section "compositor"
      if have niri && [ -n "''${NIRI_SOCKET-}" ]; then
        niri msg outputs || true
      else
        echo "not a niri session, or not run from inside one"
      fi
    '';
  };
in
{
  # local.* lives in its own module so this one can stay a config attrset.
  imports = [
    ./options.nix

    # OpenRGB: the daemon, and re-applying the profile after a suspend.
    #
    # It lived here as four lines and moved out when the resume half was added.
    # Still imported from this file rather than per host, so the hosts that had
    # RGB before still have it and nothing had to be edited to keep it. Its
    # `local.openrgb.*` options are in modules/nixos/options.nix.
    ./openrgb.nix
  ];

  # MangoHud isn't here at all: it's configured per-user in
  # home/joshr/gaming.nix, through home-manager's programs.mangohud rather than
  # a NixOS-level option. The counters it shows are chosen to match the
  # sections gaming-doctor prints — see the comment there.

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
  };

  programs.gamescope = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    prismlauncher
    protonup-qt
    lutris

    # "Why is it slow *now*" — see the comment on the derivation above, and
    # "Gaming performance" in MANUAL.md for what to do with each answer.
    gamingDoctor
  ];

  programs.gamemode = {
    enable = true;

    settings = {
      # Both hooks do three things rather than one: notify, poke waybar, and
      # hand the niri session its own GameMode — see the comments on
      # gamemodeStart and sessionGamemode above for why, and for why the start
      # half is a program while this end half is still a line of shell.
      #
      # The third of those is the only one that reaches a *different* config
      # tree. It is also the only one that has no effect at all on a Plasma
      # login, where the unit it starts does not exist; that is what the
      # trailing `|| true` on it is for, and it is why nothing here has to ask
      # which session is running.
      #
      # The `;` in `end` is real shell: gamemode runs these through
      # `/bin/sh -c` (game_mode_execute_scripts in daemon/gamemode-context.c),
      # not execvp on a split string, which is also why the quoted
      # notification title works. It is also why either side can be a bare
      # store path with no PATH to find it on — gamemoded's own PATH is
      # nearly empty.
      #
      # `|| true` because pkill exits 1 when nothing matches, which is the
      # ordinary case in a Plasma session with no waybar running, and
      # gamemoded logs a non-zero script as a failure.
      custom = {
        # Only the host with a model server on the same card needs a program
        # here; everywhere else there is nothing for the notification to say
        # that it didn't say before, and this stays the line it has always
        # been — which also keeps `gamestation` off a rebuild it gains
        # nothing from.
        start =
          if releaseOnGameMode then
            lib.getExe gamemodeStart
          else
            "${pkgs.libnotify}/bin/notify-send -i input-gamepad 'GameMode started'; ${pkgs.procps}/bin/pkill -RTMIN+9 waybar || true; ${sessionGamemode "start"}";
        end = "${pkgs.libnotify}/bin/notify-send -i input-gamepad 'GameMode ended'; ${pkgs.procps}/bin/pkill -RTMIN+9 waybar || true; ${sessionGamemode "stop"}";
      };
    };
  };
}
