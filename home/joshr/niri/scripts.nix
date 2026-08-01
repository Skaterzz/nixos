{
  config,
  lib,
  pkgs,
  niriTheming,
  ...
}:

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

  # swaylock, patched so the date stacks onto two lines and can't overhang the
  # ring.
  #
  # Upstream draws the date as one row sized at a hardcoded `arc_radius / 6`
  # (render.c), so it grows in exact proportion to the circle and a long date
  # overhangs by the same fraction at every radius. No flag reaches it —
  # `--font-size` sets the clock above it and nothing else is exposed — so a
  # wider `--indicator-radius` cannot buy the room. Without the patch the only
  # options are to shorten the date or narrow the font, and both give something
  # up: the installed fonts are FiraCode and Poppins, with nothing condensed.
  #
  # So the patch teaches it to split `--datestr` on a newline (strftime `%n`)
  # and stack the halves — weekday over month and day. Two short lines fit at
  # full size where one long one didn't: at radius 130 "Wednesday" and
  # "September 24" come out 117px and 156px against chords of 246px and 231px,
  # where the single row was 299px against 240px.
  #
  # It also scales a line down if it still wouldn't fit, bounded by the ring's
  # inner chord at that line's own baseline rather than the diameter, since the
  # date sits below the centre where the circle has already narrowed. With
  # stacking that never triggers for this format — it's the backstop that makes
  # an overhang impossible for any format or locale.
  #
  # Costs a source build of swaylock-effects, which is a small C project and
  # quick. If a nixpkgs bump ever moves those lines the patch will fail to
  # apply, and the fallback is a one-line `--datestr` short enough to fit
  # (`%a, %b %d`).
  swaylock = pkgs.swaylock-effects.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./swaylock-date-fit.patch ];
  });

  # name -> store path, as a shell case statement.
  themeCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (n: d: ''${n}) target="${d}" ;;'') themeDirs
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
  #   KDE     a palette-changed signal on the session bus. This is the
  #           mechanism Plasma itself uses when you pick a colour scheme, and
  #           plasma-integration — loaded because qt.platformTheme.name is
  #           "kde", see ./default.nix — listens for it and re-reads
  #           kdeglobals, so an open Dolphin repaints in place. Best effort:
  #           nothing guarantees a given Qt app subscribes, and anything that
  #           doesn't keeps its old palette until relaunched.
  #   VS Code nothing to send. Extensions, and therefore colour themes, are
  #           scanned once at startup; the editor picks the new palette up
  #           the next time it starts.
  #   SDDM    picked up by a system path unit watching the file written
  #           below; applies at the next greeter start. See
  #           modules/nixos/niri.nix.
  themeApply = pkgs.writeShellApplication {
    name = "theme-apply";
    runtimeInputs = with pkgs; [
      libnotify
      systemd
      procps
      dbus
    ];
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

      # Tell running KDE apps their palette changed, so an open Dolphin
      # repaints instead of waiting to be relaunched.
      #
      # This is KGlobalSettings::notifyChange, the signal Plasma emits when a
      # colour scheme is applied; the two int32 arguments are the change type
      # (0 = PaletteChanged) and an unused argument the signature still
      # requires. It is a plain broadcast — with no subscriber it goes
      # nowhere and costs nothing, which is why it is safe to send blind.
      dbus-send --session --type=signal \
        /KGlobalSettings org.kde.KGlobalSettings.notifyChange \
        int32:0 int32:0 >/dev/null 2>&1 || true

      notify-send -a theme -i preferences-desktop-theme \
        "Theme" "Switched to $name — Some apps may need to be restarted for $name to apply." || true
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

  # Jump to a random theme. This is what Mod+Shift+T runs.
  #
  # The current theme is excluded from the draw, so the key always visibly
  # does something. With 20 palettes a plain random pick would land on the
  # one already active about one press in twenty, and a keybind that
  # occasionally appears to do nothing reads as broken rather than as chance.
  #
  # themeCycle above is still built and still on PATH as `theme-cycle`; it
  # just isn't bound to anything any more. This mirrors the wallpaper keys —
  # Mod+Shift+W is random, Mod+Ctrl+W picks — so the two pairs now behave the
  # same way.
  themeRandom = pkgs.writeShellApplication {
    name = "theme-random";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      themeApply
    ];
    text = ''
      current="$(cat "${stateDir}/current" 2>/dev/null || echo "")"

      # -x so a name can't match as a substring of another, -F so nothing in
      # a theme name is read as a pattern. `|| true` because grep exits 1 when
      # it selects nothing, which under pipefail would abort the script.
      pick="$(printf '%s\n' "${themeNames}" \
                | grep -vxF -- "$current" \
                | shuf -n1 || true)"

      # Only reachable if themes.nix defines exactly one theme, in which case
      # there is nothing to switch to.
      [ -n "$pick" ] || exit 0

      theme-apply "$pick"
    '';
  };

  # Pick a theme from a wofi menu.
  themeMenu = pkgs.writeShellApplication {
    name = "theme-menu";
    runtimeInputs = with pkgs; [
      wofi
      themeApply
    ];
    text = ''
      choice="$(printf '%s\n' ${lib.escapeShellArgs (lib.attrNames themes)} | wofi --dmenu --prompt "Theme" --insensitive)"
      [ -n "$choice" ] && theme-apply "$choice"
    '';
  };

  # Wallpaper: awww daemon plus a picker over ~/.local/share/wallpapers.
  # The chosen path is remembered so it can be restored at login.
  wallpaperSet = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = with pkgs; [
      awww
      libnotify
    ];
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
    runtimeInputs = with pkgs; [
      wofi
      findutils
      coreutils
      imagemagick
      wallpaperSet
    ];
    text = ''
      dir="${wallpaperDir}"
      [ -d "$dir" ] || { echo "no wallpaper dir: $dir" >&2; exit 1; }

      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-menu"
      entries="$(mktemp)"
      mkdir -p "$cache"
      trap 'rm -f "$entries"' EXIT

      # Wofi can display image escape entries. Cache small, uniformly cropped
      # previews so opening the picker does not decode every full-resolution
      # wallpaper from scratch each time.
      while IFS= read -r img; do
        rel="''${img#"$dir"/}"
        stamp="$(stat -c '%Y:%s' "$img")"
        key="$(printf '%s\0%s' "$img" "$stamp" | sha256sum | cut -d ' ' -f1)"
        thumb="$cache/$key.jpg"

        if [ ! -f "$thumb" ]; then
          tmp="$cache/.$key.tmp.jpg"
          if magick "$img" -auto-orient \
              -thumbnail '320x180^' -gravity center -extent 320x180 \
              -strip -quality 85 "$tmp" 2>/dev/null; then
            mv -f "$tmp" "$thumb"
          else
            rm -f "$tmp"
          fi
        fi

        preview="$img"
        [ -f "$thumb" ] && preview="$thumb"
        printf 'img:%s:text:%s\n' "$preview" "$rel" >> "$entries"
      done < <(
        find -L "$dir" -type f \
          \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
          -print 2>/dev/null | sort
      )

      [ -s "$entries" ] || { echo "no wallpapers found in: $dir" >&2; exit 1; }

      choice="$(wofi --dmenu \
        --prompt "Wallpaper" \
        --insensitive \
        --allow-images \
        --parse-search \
        --no-custom-entry \
        --cache-file /dev/null \
        --width 80% \
        --lines 3 \
        --columns 4 \
        --define=image_size=180 \
        < "$entries")"

      # Depending on the wofi build, dmenu mode can return either the visible
      # label or the complete image escape. This handles both.
      choice="''${choice#*:text:}"
      [ -n "$choice" ] && wallpaper-set "$dir/$choice"
    '';
  };

  wallpaperRandom = pkgs.writeShellApplication {
    name = "wallpaper-random";
    runtimeInputs = with pkgs; [
      findutils
      coreutils
      wallpaperSet
    ];
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
    runtimeInputs = [
      pkgs.awww
      wallpaperSet
      wallpaperRandom
    ];
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

  # Where the last selected region is remembered. Its own directory rather
  # than niri-theme/ next to the wallpaper: that one is named for the theme
  # state it holds, and a screenshot region isn't part of a theme.
  screenshotStateDir = "${config.home.homeDirectory}/.local/state/niri-screenshot";

  # Annotated region capture: slurp selects, grim captures, satty annotates
  # and writes the result.
  #
  # Plain screen and window captures are bound straight to niri's built-in
  # `screenshot-screen` / `screenshot-window` actions instead — the compositor
  # already knows the exact geometry, so there's nothing for a script to
  # compute and get wrong.
  #
  # Two modes:
  #
  #   screenshot          select a region, remember it, capture it
  #   screenshot last     capture the remembered region again, no selection
  #
  # `last` is for the repeat case — the same panel or window region, shot over
  # and over, where redrawing the selection by hand each time is the tedious
  # part and is also what makes the frames not line up.
  #
  # slurp has no way to *pre-fill* a selection, which is why this is a separate
  # mode rather than "reopen slurp with last time's box ready to nudge". Its
  # `-r` reads boxes on stdin and restricts the selection to them, so feeding
  # it the saved region would let you click that box to accept it but never
  # drag its edges — a worse version of `last`, with an extra click.
  #
  # The saved geometry is grim's own `X,Y WxH`, straight from slurp and passed
  # back to grim unparsed. Nothing here needs to understand it, so nothing here
  # can misparse it.
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
      mkdir -p "${screenshotDir}" "${screenshotStateDir}"
      region="${screenshotStateDir}/region"
      mode="''${1:-select}"

      # Month-day-year on a 12-hour clock, matching niri's own
      # `screenshot-path` and every other clock in the session. The cost is
      # that filenames no longer sort chronologically; "%Y-%m-%d_%H-%M-%S"
      # is the string to put back in both places if that matters more.
      stamp="$(date '+%m-%d-%Y_%I-%M-%S-%p')"
      out="${screenshotDir}/screenshot_$stamp.png"

      # grim writes to a file rather than down a pipe into satty, so that a
      # geometry it rejects is catchable here. Piping would only surface as a
      # pipefail exit after satty had already been handed nothing.
      shot="$(mktemp -t screenshot-XXXXXXXX.png)"
      trap 'rm -f "$shot"' EXIT

      geom=""
      if [ "$mode" = "last" ]; then
        geom="$(cat "$region" 2>/dev/null || true)"
      fi

      # A remembered region can stop being valid — a monitor unplugged, or the
      # layout rearranged under it. Fall through to a fresh selection rather
      # than failing, since the point of the key is to be quick.
      if [ -n "$geom" ] && ! grim -g "$geom" "$shot" 2>/dev/null; then
        notify-send -a screenshot \
          "Screenshot" "Last region isn't on screen any more — select a new one."
        geom=""
      fi

      if [ -z "$geom" ]; then
        # Cancelled selection exits non-zero; that's not an error.
        geom="$(slurp -d -b '#0a0e0acc' -c '#39ff14' -s '#39ff1420' -w 2)" || exit 0
        grim -g "$geom" "$shot"

        # Only after grim accepts it, so a region that can't be captured is
        # never the one `last` comes back to.
        printf %s "$geom" > "$region"
      fi

      satty --filename "$shot" \
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
  #
  # `--color` is the flat colour swaylock paints *underneath* the screenshot
  # background, and it is what you actually see whenever there is no
  # screenshot to draw over it. Its default is white, so leaving it off is
  # what made the lock screen come up blank white with a monitor powered off.
  #
  # `--screenshots` captures each output through wlr-screencopy at lock time,
  # and a capture of an output that is currently blanked fails. In the
  # packaged fork (jirutka's swaylock-effects 1.7.0.0) that failure handler
  # clears `args.screenshots` on the shared state rather than on the one
  # surface that failed, so a single blanked monitor takes the screenshot
  # background away from *every* display — hence full white everywhere, not
  # just on the display that was off. Pointing --color at the theme
  # background turns that fallback into a themed solid colour.
  #
  # It's reachable in normal use because the blank and the lock are
  # independent: Mod+Escape blanks on demand, and swayidle blanks at 360s and
  # locks before sleep, so "outputs off" and "now lock" overlap easily.
  #
  # niri's `layout { background-color }` has no bearing on this. That is the
  # backdrop behind windows; swaylock's own surface covers it.
  #
  # The `%n` in `--datestr` is the line break that stacks the weekday over the
  # month and day. Stock swaylock would draw it as a literal newline character
  # in one row; reading it as a break is the patch on `swaylock` above, which
  # is also what keeps the date from overhanging. See the comment there.
  #
  # Thickness moves 8 → 9 with the radius (110 → 130) only to hold the ring's
  # weight steady; at 8 a 130 ring reads visibly thinner than the 110 one did.
 lockSession = pkgs.writeShellApplication {
  name = "lock-session";

  runtimeInputs = [
    pkgs.hyprlock
    pkgs.coreutils
    pkgs.gawk
    pkgs.glibc.bin
    swaylock
  ];

  text = ''
    # shellcheck disable=SC1091
    if [ -r "${activeDir}/swaylock.env" ]; then
      . "${activeDir}/swaylock.env"
    fi

    : "''${LOCK_BG:=0a0e0a}"
    : "''${LOCK_ACCENT:=39ff14}"
    : "''${LOCK_ACCENT_DIM:=1f8b0d}"
    : "''${LOCK_FG:=c8f5c8}"
    : "''${LOCK_FG_DIM:=5c7a5c}"
    : "''${LOCK_ERR:=ff5555}"
    : "''${LOCK_WARN:=f5d76e}"

    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    config="$runtime_dir/hyprlock-niri.conf"

    mkdir -p "$runtime_dir"
    umask 077

    # Resolve the account through NSS, read its full-name/GECOS field, and
    # take the first whitespace-delimited word. This works for local users
    # and NSS-backed users instead of reading /etc/passwd directly.
    user="''${USER:-$(id -un)}"

    first_name="$(
      getent passwd "$user" 2>/dev/null |
        awk -F: '
          {
            split($5, gecos, ",")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", gecos[1])
            split(gecos[1], words, /[[:space:]]+/)
            print words[1]
            exit
          }
        ' || true
    )"

    # Remove characters that could break the generated Hyprlang line.
    first_name="$(printf %s "$first_name" | tr -d '\r\n{}"#')"
    [ -n "$first_name" ] || first_name="$user"

    # Hyprlock gets a fixed, punctuation-free path. The selected wallpaper
    # itself may contain spaces or characters meaningful to Hyprlang.
    wallpaper="$(cat "${stateDir}/wallpaper" 2>/dev/null || true)"
    path_line=""

    rm -f "$runtime_dir"/hyprlock-wallpaper.*

    if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
      extension="$(
        printf %s "''${wallpaper##*.}" |
          tr '[:upper:]' '[:lower:]'
      )"

      case "$extension" in
        png | jpg | jpeg | webp)
          wallpaper_link="$runtime_dir/hyprlock-wallpaper.$extension"
          ln -sfn -- "$wallpaper" "$wallpaper_link"
          path_line="    path = $wallpaper_link"
          ;;
      esac
    fi

    cat > "$config" <<EOF
    general {
        hide_cursor = true
        ignore_empty_input = true
        immediate_render = true
        text_trim = true
        fail_timeout = 1800
    }

    auth {
        pam:enabled = true
        pam:module = hyprlock
    }

    animations {
        enabled = true

        bezier = graceful, 0.22, 1, 0.36, 1

        animation = fadeIn, 1, 2.4, graceful
        animation = fadeOut, 1, 2.0, graceful
        animation = inputFieldDots, 1, 2.8, graceful
        animation = inputFieldColors, 1, 2.2, graceful
        animation = inputFieldFade, 1, 2.2, graceful
    }

    background {
        monitor =
    $path_line
        color = rgb($LOCK_BG)

        blur_passes = 3
        blur_size = 8

        noise = 0.012
        contrast = 1.0
        brightness = 0.72
        vibrancy = 0.16
        vibrancy_darkness = 0.12
    }

    # Quiet clock above the greeting.
    label {
        monitor =
        text = \$TIME12
        color = rgba(''${LOCK_FG}dd)
        font_size = 72
        font_family = Poppins

        position = 0, 125
        halign = center
        valign = center
    }

    # The account's configured full name supplies this first name.
    label {
        monitor =
        text = Welcome, $first_name
        color = rgb($LOCK_FG)
        font_size = 40
        font_family = Poppins

        position = 0, 35
        halign = center
        valign = center
    }

    # One low, horizontal password field. Dots begin at the left and animate
    # individually so typing travels across the line rather than accumulating
    # as a static cluster in its center.
    input-field {
        monitor =

        size = 620, 58
        outline_thickness = 2
        rounding = 18

        dots_size = 0.15
        dots_spacing = 0.42
        dots_center = false
        dots_rounding = -1
        dots_text_format = •

        outer_color = rgba(''${LOCK_ACCENT_DIM}dd)
        inner_color = rgba(''${LOCK_BG}d6)
        font_color = rgb($LOCK_FG)
        font_family = FiraCode Nerd Font

        fade_on_empty = false
        hide_input = false
        placeholder_text = Password

        check_color = rgb($LOCK_ACCENT)
        check_text = Unlocking…

        fail_color = rgb($LOCK_ERR)
        fail_text = <i>\$FAIL</i>

        capslock_color = rgb($LOCK_WARN)

        position = 0, 72
        halign = center
        valign = bottom
    }
    EOF

    # Hyprlock blocks until the session is unlocked. A nonzero exit here
    # means it failed to initialize, not merely that a password was wrong.
    if hyprlock --config "$config" --grace 2; then
      exit 0
    fi

    # Last-resort locker. Even a Hyprlock regression must not leave the
    # session exposed.
    image_args=()
    if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
      image_args=(
        --image ":$wallpaper"
        --scaling fill
      )
    fi

    exec swaylock \
      "''${image_args[@]}" \
      --color "$LOCK_BG" \
      --clock \
      --indicator \
      --indicator-radius 130 \
      --indicator-thickness 9 \
      --effect-blur 8x5 \
      --effect-vignette 0.4:0.4 \
      --datestr "%A%n%B %d" \
      --timestr "%I:%M %p" \
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
    runtimeInputs = with pkgs; [
      systemd
      libnotify
      procps
    ];
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
    runtimeInputs = with pkgs; [
      dbus
      lockSession
    ];
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

  # Brightness, across every backlight device rather than only the first.
  #
  # `brightnessctl set` with no --device picks the first device it finds and
  # adjusts that one alone. On the laptop there is exactly one — the internal
  # panel — so that was invisible. The desk reaches its monitors through
  # ddcci-backlight (modules/nixos/ddcci.nix), which registers one device per
  # display, and "the first one" there means a single monitor changes and the
  # other doesn't. Hence the loop.
  #
  # Also the reason the keybinds call this rather than brightnessctl directly:
  # a host with one display and a host with two want the same key to mean the
  # same thing.
  brightness = pkgs.writeShellApplication {
    name = "brightness";
    runtimeInputs = with pkgs; [
      brightnessctl
      util-linux
      coreutils
    ];
    text = ''
      step=5

      # Serialise, and drop overlapping runs rather than queue them.
      #
      # A DDC/CI write is a round trip over the monitor's own i2c bus, on the
      # order of 100ms per display — the kernel backlight of a laptop panel is
      # effectively instant by comparison. Holding the key down generates
      # presses far faster than the monitors can answer, and without this the
      # backlog keeps applying for seconds after the key is released. -n makes
      # a run that arrives mid-write exit instead of waiting its turn.
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/brightness.lock"
      flock -n 9 || exit 0

      # Machine-readable list is `name,class,current,percent%,max` per device.
      #
      # The process substitution keeps a non-zero brightnessctl — which is
      # what an empty backlight class produces, the ordinary state of a
      # desktop without ddcci loaded — from tripping `set -e` here, so the
      # empty case gets a clear message instead of a bare failure.
      mapfile -t devices < <(
        brightnessctl --class=backlight --machine-readable --list 2>/dev/null | cut -d, -f1
      )

      if [ ''${#devices[@]} -eq 0 ]; then
        echo "brightness: no backlight devices — see modules/nixos/ddcci.nix" >&2
        exit 1
      fi

      # One monitor refusing a DDC/CI write shouldn't stop the others moving.
      apply() {
        local dev="$1"
        shift
        brightnessctl --class=backlight --device="$dev" --quiet "$@" || true
      }

      each() {
        local dev
        for dev in "''${devices[@]}"; do
          apply "$dev" "$@"
        done
      }

      case "''${1:-}" in
        up)   each set "+''${step}%" ;;
        down) each set "''${step}%-" ;;
        set)
          [ -n "''${2:-}" ] || { echo "usage: brightness set <percent>" >&2; exit 2; }
          each set "$2%"
          ;;
        # Save the current level and drop to <percent>. This is the swayidle
        # dim warning; `restore` is its resumeCommand.
        dim)
          [ -n "''${2:-}" ] || { echo "usage: brightness dim <percent>" >&2; exit 2; }
          each --save set "$2%"
          ;;
        restore) each --restore ;;
        *)
          echo "usage: brightness [up|down|set <pct>|dim <pct>|restore]" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Audio visualiser for the bar. See the custom/cava module in waybar.nix.
  cavaConfig = pkgs.writeText "cava-waybar.conf" ''
    [general]
    # Eight glyphs in a status bar, not a full-screen visualiser — and every
    # frame is a waybar label redraw, so 30 rather than cava's default 60.
    framerate = 30
    bars = 8
    autosens = 1

    # After two seconds of silence cava stops doing FFT and just checks for
    # input once a second, until sound comes back. Nothing is playing most of
    # the time, and this is meant to be a detail rather than a background job.
    sleep_timer = 2

    [input]
    # pipewire-pulse is on (modules/nixos/niri.nix), and `pulse` with
    # `source = auto` follows the *default sink's* monitor — so it tracks
    # whichever output you switched to instead of a device named here.
    method = pulse
    source = auto

    [output]
    method = raw
    raw_target = /dev/stdout
    data_format = ascii
    # 0-7, one value per block glyph in the mapping below.
    ascii_max_range = 7
  '';

  # Eight bars of the playing audio, or nothing at all when it's quiet.
  #
  # Emitting an empty line is what hides it: waybar hides a custom module
  # whose text is empty. So the bar looks exactly as it did before whenever
  # the music stops, which is the point — the widget doesn't reserve a slot
  # or leave a flat row of glyphs sitting there.
  #
  # It follows *audio*, not the mpris player, so a notification chime blips it
  # for a moment too. That's deliberate: it needs no polling and no second
  # process, and it reacts within a frame. To tie it to the player instead,
  # the gate would have to be `playerctl --follow status` feeding this loop.
  #
  # No stdbuf anywhere in here, and it isn't an oversight — cava's raw output
  # is plain write(2) with no stdio buffer (output/raw.c), and bash flushes
  # its printf per iteration, so frames arrive one at a time on their own.
  cavaBar = pkgs.writeShellApplication {
    name = "cava-bar";
    runtimeInputs = [ pkgs.cava ];
    text = ''
      cava -p ${cavaConfig} | while IFS= read -r frame; do
        # `0;3;5;7;` -> `0357`
        bars="''${frame//;/}"

        # An all-zero frame is silence. Anything at all in 1-7 is sound.
        case "$bars" in
          *[1-7]*) ;;
          *) echo; continue ;;
        esac

        # Parameter substitution rather than sed or tr: this runs thirty times
        # a second, and a process per frame is not the way to draw a
        # decoration. The replacements can't collide — every result is a
        # non-digit.
        bars="''${bars//0/▁}"
        bars="''${bars//1/▂}"
        bars="''${bars//2/▃}"
        bars="''${bars//3/▄}"
        bars="''${bars//4/▅}"
        bars="''${bars//5/▆}"
        bars="''${bars//6/▇}"
        bars="''${bars//7/█}"

        printf '%s\n' "$bars"
      done
    '';
  };
in
{
  home.packages = [
    themeApply
    themeCycle
    themeRandom
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
    brightness
    cavaBar
  ];

  _module.args.niriScripts = {
    inherit
      themeApply
      themeCycle
      themeRandom
      themeMenu
      wallpaperMenu
      wallpaperRandom
      wallpaperRestore
      screenshot
      lockSession
      switchUser
      sessionMenu
      idleInhibit
      brightness
      cavaBar
      ;

    # Not a script: the patched swaylock that lock-session wraps. Exported so
    # lock.nix installs the same build rather than the stock one, which would
    # otherwise put an unpatched `swaylock` on PATH beside it.
    inherit swaylock;
  };
}
