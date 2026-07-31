{ config, lib, pkgs, niriTheming, ... }:

# Runtime helpers, all built as store scripts and bound to keys in config.kdl.
#
# The theme switcher only ever moves one symlink (see theming.nix) and then
# nudges each tool to re-read its config. Nothing writes generated content at
# runtime.
let
  inherit (niriTheming)
    themes
    themeDirs
    stateDir
    activeDir
    ;

  wallpaperDir = "${config.home.homeDirectory}/.local/share/wallpapers";

  # name -> store path, as a shell case statement.
  themeCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (n: d: ''      ${n}) target="${d}" ;;'') themeDirs
  );

  themeNames = lib.concatStringsSep "\n" (lib.attrNames themes);

  # Apply a theme by name: repoint the symlink, then reload consumers.
  #
  #   niri    watches its config and the include target changed, so it
  #           reloads on its own.
  #   waybar  restarted. It's started with `-s <active>/waybar.css`, and a
  #           restart is the only way to be sure the stylesheet is re-read —
  #           SIGUSR2 alone did not reliably repaint.
  #   dunst   restarted; it's launched with `-config <active>/dunstrc`.
  #   wofi    nothing — it reads its stylesheet fresh on each launch.
  #   kitty   SIGUSR1, which is kitty's documented "re-read kitty.conf"
  #           signal. It follows the include and repaints open windows, so
  #           running terminals change colour in place.
  #   KDE     nothing to send. Dolphin and friends read kdeglobals once at
  #           startup, so an open window keeps its old palette until
  #           relaunched.
  #   firefox nothing to send either — userChrome.css is read while the
  #           browser starts, and there is no supported way to make a running
  #           Firefox re-read it. Same deal as Dolphin: next launch.
  #   SDDM    picked up by a system path unit watching the file written
  #           below; applies at the next greeter start. See
  #           modules/nixos/niri.nix.
  themeApply = pkgs.writeShellApplication {
    name = "theme-apply";
    runtimeInputs = with pkgs; [ libnotify systemd procps ];
    text = ''
      name="''${1:-}"
      if [ -z "$name" ]; then
        echo "usage: theme-apply <name>" >&2
        exit 2
      fi

      target=""
      case "$name" in
      ${themeCases}
        *) echo "unknown theme: $name" >&2; exit 1 ;;
      esac

      mkdir -p "${stateDir}"
      ln -sfn "$target" "${activeDir}"
      printf %s "$name" > "${stateDir}/current"

      systemctl --user restart waybar.service || true
      systemctl --user restart dunst.service || true

      # -x so this matches the kitty process and not, say, an editor that
      # happens to have "kitty" in its command line. Non-zero simply means no
      # terminal is open.
      pkill -USR1 -x kitty || true

      notify-send -a theme -i preferences-desktop-theme \
        "Theme" "Switched to $name" || true
    '';
  };

  # Cycle to the next theme in the list, wrapping around. Bound to a key.
  themeCycle = pkgs.writeShellApplication {
    name = "theme-cycle";
    runtimeInputs = [ themeApply ];
    text = ''
      themes="${themeNames}"
      current="$(cat "${stateDir}/current" 2>/dev/null || echo "")"

      next="$(echo "$themes" | awk -v cur="$current" '
        { list[NR] = $0 }
        END {
          for (i = 1; i <= NR; i++) if (list[i] == cur) { print list[i % NR + 1]; exit }
          print list[1]
        }')"

      theme-apply "$next"
    '';
  };

  # Pick a theme from a wofi menu.
  themeMenu = pkgs.writeShellApplication {
    name = "theme-menu";
    runtimeInputs = with pkgs; [ wofi themeApply ];
    text = ''
      choice="$(printf '%s\n' ${
        lib.escapeShellArgs (lib.attrNames themes)
      } | wofi --dmenu --prompt "Theme" --insensitive)"
      [ -n "$choice" ] && theme-apply "$choice"
    '';
  };

  # Wallpaper: awww daemon plus a picker over ~/.local/share/wallpapers.
  # The chosen path is remembered so it can be restored at login.
  wallpaperSet = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = with pkgs; [ awww libnotify ];
    text = ''
      img="''${1:-}"
      [ -z "$img" ] && { echo "usage: wallpaper-set <image>" >&2; exit 2; }
      [ -f "$img" ] || { echo "no such file: $img" >&2; exit 1; }

      # Start the daemon if it isn't already up.
      awww query >/dev/null 2>&1 || { awww-daemon & sleep 0.5; }

      awww img "$img" \
        --transition-type grow \
        --transition-pos center \
        --transition-duration 1 \
        --transition-fps 60

      mkdir -p "${stateDir}"
      printf %s "$img" > "${stateDir}/wallpaper"
    '';
  };

  wallpaperMenu = pkgs.writeShellApplication {
    name = "wallpaper-menu";
    runtimeInputs = with pkgs; [ wofi findutils coreutils wallpaperSet ];
    text = ''
      dir="${wallpaperDir}"
      [ -d "$dir" ] || { echo "no wallpaper dir: $dir" >&2; exit 1; }

      # -L so the symlink home-manager creates into the dotfiles store path
      # is followed.
      choice="$(find -L "$dir" -type f \
                  \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
                  -printf '%P\n' 2>/dev/null \
                | sort \
                | wofi --dmenu --prompt "Wallpaper" --insensitive)"

      [ -n "$choice" ] && wallpaper-set "$dir/$choice"
    '';
  };

  wallpaperRandom = pkgs.writeShellApplication {
    name = "wallpaper-random";
    runtimeInputs = with pkgs; [ findutils coreutils wallpaperSet ];
    text = ''
      dir="${wallpaperDir}"
      [ -d "$dir" ] || exit 0
      pick="$(find -L "$dir" -type f \
                \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
              2>/dev/null | shuf -n1)"
      [ -n "$pick" ] && wallpaper-set "$pick"
    '';
  };

  # Restore the remembered wallpaper at login, falling back to a random one.
  wallpaperRestore = pkgs.writeShellApplication {
    name = "wallpaper-restore";
    runtimeInputs = [ pkgs.awww wallpaperSet wallpaperRandom ];
    text = ''
      awww query >/dev/null 2>&1 || { awww-daemon & sleep 0.5; }
      saved="$(cat "${stateDir}/wallpaper" 2>/dev/null || echo "")"
      if [ -n "$saved" ] && [ -f "$saved" ]; then
        wallpaper-set "$saved"
      else
        wallpaper-random
      fi
    '';
  };

  screenshotDir = "${config.home.homeDirectory}/Pictures/Screenshots";

  # Annotated region capture: slurp selects, grim captures, satty annotates
  # and writes the result.
  #
  # Plain screen and window captures are bound straight to niri's built-in
  # `screenshot-screen` / `screenshot-window` actions instead — the compositor
  # already knows the exact geometry, so there's nothing for a script to
  # compute and get wrong.
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      grim
      slurp
      satty
      wl-clipboard
      libnotify
      coreutils
    ];
    text = ''
      mkdir -p "${screenshotDir}"
      stamp="$(date +%Y-%m-%d_%H-%M-%S)"
      out="${screenshotDir}/screenshot_$stamp.png"

      # Cancelled selection exits non-zero; that's not an error.
      geom="$(slurp -d -b '#0a0e0acc' -c '#39ff14' -s '#39ff1420' -w 2)" || exit 0

      grim -g "$geom" - \
        | satty --filename - \
            --output-filename "$out" \
            --early-exit \
            --copy-command wl-copy

      if [ -f "$out" ]; then
        notify-send -a screenshot -i "$out" "Screenshot" "Saved $(basename "$out")"
      fi
    '';
  };

  # Lock the session. Colours come from the active theme's swaylock.env, so
  # the lock screen follows whatever theme is current.
  lockSession = pkgs.writeShellApplication {
    name = "lock-session";
    runtimeInputs = with pkgs; [ swaylock-effects ];
    text = ''
      # shellcheck disable=SC1091
      if [ -r "${activeDir}/swaylock.env" ]; then . "${activeDir}/swaylock.env"; fi

      : "''${LOCK_BG:=0a0e0a}"
      : "''${LOCK_ACCENT:=39ff14}"
      : "''${LOCK_ACCENT_DIM:=1f8b0d}"
      : "''${LOCK_FG:=c8f5c8}"
      : "''${LOCK_FG_DIM:=5c7a5c}"
      : "''${LOCK_ERR:=ff5555}"
      : "''${LOCK_WARN:=f5d76e}"

      exec swaylock \
        --screenshots \
        --clock \
        --indicator \
        --indicator-radius 110 \
        --indicator-thickness 8 \
        --effect-blur 8x5 \
        --effect-vignette 0.4:0.4 \
        --datestr "%A, %d %B" \
        --timestr "%H:%M" \
        --font "FiraCode Nerd Font" \
        --ring-color "$LOCK_ACCENT_DIM" \
        --ring-clear-color "$LOCK_WARN" \
        --ring-ver-color "$LOCK_ACCENT" \
        --ring-wrong-color "$LOCK_ERR" \
        --key-hl-color "$LOCK_ACCENT" \
        --bs-hl-color "$LOCK_ERR" \
        --inside-color "$LOCK_BG"cc \
        --inside-clear-color "$LOCK_BG"cc \
        --inside-ver-color "$LOCK_BG"cc \
        --inside-wrong-color "$LOCK_BG"cc \
        --line-color 00000000 \
        --line-clear-color 00000000 \
        --line-ver-color 00000000 \
        --line-wrong-color 00000000 \
        --separator-color 00000000 \
        --text-color "$LOCK_FG" \
        --text-clear-color "$LOCK_FG" \
        --text-ver-color "$LOCK_FG" \
        --text-wrong-color "$LOCK_ERR" \
        --fade-in 0.2 \
        --grace 2
    '';
  };

  # Sleep inhibitor. One entry point for the keybind and the waybar module,
  # so the two can't disagree about the state.
  #
  # All the actual work is in idle-inhibit.service (lock.nix); this only
  # starts and stops it. systemd holding the state means `status` is a real
  # query rather than a flag file that can go stale — if the inhibitor dies
  # for any reason, the bar shows it.
  #
  # Not waybar's built-in `idle_inhibitor` module: that one holds a Wayland
  # idle-inhibit lock on waybar's own surface, which is a fine mechanism but
  # can only be toggled by clicking the module. There's no IPC to it, so a
  # keybind would have no way in. It also wouldn't hold off logind sleep.
  idleInhibit = pkgs.writeShellApplication {
    name = "idle-inhibit";
    runtimeInputs = with pkgs; [ systemd libnotify procps ];
    text = ''
      unit=idle-inhibit.service

      is_on() { systemctl --user is-active --quiet "$unit"; }

      case "''${1:-toggle}" in
        on)  systemctl --user start "$unit" ;;
        off) systemctl --user stop  "$unit" ;;
        toggle)
          if is_on; then systemctl --user stop "$unit"
          else systemctl --user start "$unit"
          fi
          ;;
        status)
          # waybar custom module, return-type json.
          if is_on; then
            printf '%s\n' '{"text":"󰅶","class":"activated","tooltip":"Awake — no dim, lock, blank or sleep"}'
          else
            printf '%s\n' '{"text":"󰒲","class":"deactivated","tooltip":"Idle actions normal — click to stay awake"}'
          fi
          exit 0
          ;;
        *)
          echo "usage: idle-inhibit [toggle|on|off|status]" >&2
          exit 2
          ;;
      esac

      # Refresh the bar now rather than waiting for its next poll. waybar
      # re-runs a custom module on SIGRTMIN+<signal>; 8 is the number set on
      # the module in waybar.nix.
      pkill -RTMIN+8 waybar || true

      if is_on; then
        notify-send -a idle-inhibit -i preferences-desktop-screensaver \
          "Staying awake" "Idle actions and sleep are inhibited" || true
      else
        notify-send -a idle-inhibit -i preferences-desktop-screensaver \
          "Idle actions restored" "Screen will dim, lock and blank as usual" || true
      fi
    '';
  };

  # Session menu: shown by the waybar power button and a hotkey.
  # Switch to the login greeter, leaving this session running on its own VT.
  #
  # SDDM implements the org.freedesktop.DisplayManager D-Bus interface, whose
  # Seat object has SwitchToGreeter — that's the supported way to do this;
  # there's no CLI equivalent. SDDM exports the seat path as XDG_SEAT_PATH in
  # the session, with Seat0 as the fallback for a single-seat machine.
  #
  # The session is locked first. SwitchToGreeter doesn't lock anything, so
  # without this, switching back would land straight in an unlocked desktop.
  switchUser = pkgs.writeShellApplication {
    name = "switch-user";
    runtimeInputs = with pkgs; [ dbus lockSession ];
    text = ''
      seat="''${XDG_SEAT_PATH:-/org/freedesktop/DisplayManager/Seat0}"

      # Lock in the background — lock-session blocks until unlocked.
      lock-session &
      sleep 0.3

      dbus-send --system --print-reply \
        --dest=org.freedesktop.DisplayManager \
        "$seat" \
        org.freedesktop.DisplayManager.Seat.SwitchToGreeter
    '';
  };

  sessionMenu = pkgs.writeShellApplication {
    name = "session-menu";
    runtimeInputs = with pkgs; [
      wofi
      systemd
      niri
      lockSession
      switchUser
    ];
    text = ''
      choice="$(printf '%s\n' \
        "  Lock" \
        "  Switch user" \
        "  Log out" \
        "  Suspend" \
        "  Reboot" \
        "  Shut down" \
        | wofi --dmenu --prompt "Session" --insensitive --width 260 --height 300)"

      case "$choice" in
        *Lock*)        lock-session ;;
        *"Switch user"*) switch-user ;;
        *"Log out"*)   niri msg action quit --skip-confirmation ;;
        *Suspend*)     systemctl suspend ;;
        *Reboot*)      systemctl reboot ;;
        *"Shut down"*) systemctl poweroff ;;
      esac
    '';
  };
in
{
  home.packages = [
    themeApply
    themeCycle
    themeMenu
    wallpaperSet
    wallpaperMenu
    wallpaperRandom
    wallpaperRestore
    screenshot
    lockSession
    switchUser
    sessionMenu
    idleInhibit
  ];

  _module.args.niriScripts = {
    inherit
      themeApply
      themeCycle
      themeMenu
      wallpaperMenu
      wallpaperRandom
      wallpaperRestore
      screenshot
      lockSession
      switchUser
      sessionMenu
      idleInhibit
      ;
  };
}
