{ config, inputs, lib, pkgs, ... }:

# System side of the niri desktop: the session itself, the display manager,
# and the bits home-manager can't write (PAM, polkit, system services).
#
# This replaces modules/nixos/desktop.nix on a host — importing both would
# enable two desktop sessions and two display managers.
let
  themeSet = import ../../home/joshr/niri/themes.nix { inherit lib; };
  inherit (themeSet) themes;

  # The palette the greeter is *built* with, and nothing more.
  #
  # This used to be a whole table: one sddm-astronaut derivation per palette in
  # themes.nix plus one per Noctalia builtin, with an /etc drop-in naming
  # whichever of them `~/.local/state/niri-theme/current` selected. That shape
  # came from the waybar stack, where the theme really was one of a finite list
  # and the greeter could be pointed at a prebuilt match.
  #
  # Under Noctalia it cannot work, and it did not: the palette can be derived
  # from a wallpaper or downloaded from api.noctalia.dev, so there is no Nix
  # derivation for it and `current` reads `noctalia-live` — a name no arm of
  # that case ever matched, which left the login screen wearing the default
  # palette regardless of what the desktop was wearing.
  #
  # So there is one theme package now, its colours come from a file under
  # /var/lib written at runtime, and this is only what that file is seeded
  # with before Noctalia has ever run.
  seedTheme = themes.${themeSet.default};

  # The user's current wallpaper, copied somewhere the greeter can read it.
  # See sddm-theme-sync below — the path is fixed so the theme config can name
  # it from the store while the image behind it changes at runtime.
  sddmWallpaper = "/var/lib/sddm-theme/wallpaper.png";

  sddmThemeConfig =
    t:
    {
      # --- background ---------------------------------------------------
      # The wallpaper should be visible, so the dim is light and the blur is
      # gentle. PartialBlur keeps the blur to the strip behind the form and
      # drops that panel to 0.3 opacity, so the picture reads through there
      # too; FullBlur would fog the whole screen.
      Background = "file://${sddmWallpaper}";
      CropBackground = "true";
      BackgroundHorizontalAlignment = "center";
      BackgroundVerticalAlignment = "center";
      FullBlur = "false";
      PartialBlur = "true";
      Blur = "1.4";
      BlurMax = "32";
      DimBackground = "0.2";

      # --- form ---------------------------------------------------------
      # Clock and login sit in a column on the right, leaving the rest of the
      # wallpaper clear. Still vertically centred — the theme has no vertical
      # position setting, so moving it lower would need a QML patch.
      HaveFormBackground = "true";
      FormPosition = "right";
      RoundCorners = "24";
      ScreenPadding = "0";

      # Land on the password field for the last user; no username step.
      ForceLastUser = "true";
      PasswordFocus = "true";
      UseRealName = "true";
      HideCompletePassword = "true";
      HideVirtualKeyboard = "true";
      HideSystemButtons = "false";

      # The clock is the header; a "Welcome" string on top of it is noise.
      HeaderText = "";

      # Qt date/time format strings, not strftime: `h` is the hour without a
      # leading zero and drops to 1–12 as soon as an AM/PM field is present,
      # and `AP` is that field. Month before day, same as the session.
      #
      # No comma in DateFormat, and that is load-bearing rather than
      # typographic. SDDM reads a theme's config with
      # `QSettings(path, QSettings::IniFormat)` (src/common/ThemeConfig.cpp),
      # and QSettings' INI format treats an unquoted comma as a *list*
      # separator — so "dddd, MMMM d" comes back as the two-element list
      # ["dddd", "MMMM d"] rather than as a string. Clock.qml then hands that
      # list to `Date.toLocaleDateString(locale, format)`, which accepts a
      # string or a format enum and nothing else, and the month goes missing.
      #
      # A middle dot separates the fields instead. Quoting the value would
      # also work — QSettings strips surrounding quotes, which is the
      # documented remedy — but that leaves a file whose correctness depends
      # on the reader being QSettings, and this doesn't.
      HourFormat = "h:mm AP";
      DateFormat = "dddd · MMMM d";

      HeaderTextColor = t.accent;
      DateTextColor = t.fg;
      TimeTextColor = t.accent;
      FormBackgroundColor = t.bg;
      BackgroundColor = t.bg;
      DimBackgroundColor = "#000000";
      LoginFieldBackgroundColor = t.bgAlt;
      PasswordFieldBackgroundColor = t.bgAlt;
      LoginFieldTextColor = t.fg;
      PasswordFieldTextColor = t.fg;
      UserIconColor = t.accent;
      PasswordIconColor = t.accent;
      PlaceholderTextColor = t.fgDim;
      WarningColor = t.err;
      LoginButtonTextColor = t.bg;
      LoginButtonBackgroundColor = t.accent;
      SystemButtonsIconsColor = t.accent;
      SessionButtonTextColor = t.fg;
      VirtualKeyboardButtonTextColor = t.fg;
      DropdownTextColor = t.fg;
      DropdownSelectedBackgroundColor = t.accentDim;
      DropdownBackgroundColor = t.bgAlt;
      HighlightTextColor = t.bg;
      HighlightBackgroundColor = t.accent;
      HighlightBorderColor = t.accent;
      HoverUserIconColor = t.fg;
      HoverSystemButtonsIconsColor = t.fg;

      Font = "Poppins";
      FontSize = "12";
    };

  # Where the greeter's colours actually live.
  #
  # `Themes/<embeddedTheme>.conf.user`, and getting that path wrong is what
  # kept the login screen off the desktop's palette. SDDM reads a theme's
  # config in two halves — `ThemeConfig::setTo` opens the file named by
  # `ConfigFile=` in metadata.desktop, then opens the same path with `.user`
  # appended and lets every non-empty value there win. nixpkgs' sddm-astronaut
  # builds on exactly that: `themeConfig` is written to
  # `Themes/${embeddedTheme}.conf.user`.
  #
  # The previous version replaced `theme.conf` in the theme's root directory
  # instead. Nothing reads that file — metadata.desktop points at
  # `Themes/black_hole.conf` — so the symlink to /var/lib was inert and the
  # greeter kept rendering the store `.conf.user` nixpkgs had written from the
  # build-time palette. Every other part of the runtime path worked; the
  # colours were being delivered to a file SDDM never opened.
  sddmEmbeddedTheme = "black_hole";
  sddmRuntimeConfig = "/var/lib/sddm-theme/theme.conf";

  iniFormat = pkgs.formats.ini { };

  # What the sync starts from and rewrites the colours of. Everything that is
  # *not* a colour — the background path, the form's position, the clock's
  # format strings, the font — is settled here at build time and never touched
  # at runtime, so the sync script only has to know about the palette.
  sddmRuntimeSeed = iniFormat.generate "sddm-noctalia-live.conf" {
    General = sddmThemeConfig seedTheme;
  };

  # One theme package, whose only mutable part is that one symlink.
  #
  # `themeConfig` is deliberately not passed to the override: it would write a
  # store file to the very path this replaces, and two writers for one file is
  # the confusion that produced the bug above. The seed reaches the greeter
  # through the sync instead, which copies it and substitutes the palette.
  sddmTheme =
    (pkgs.sddm-astronaut.override {
      embeddedTheme = sddmEmbeddedTheme;
    }).overrideAttrs
      (old: {
        pname = "sddm-astronaut-niri";
        postInstall = (old.postInstall or "") + ''
          themeDir="$out/share/sddm/themes/sddm-astronaut-theme"
          chmod -R u+w "$themeDir"

          # Force the password field to mask immediately.
          #
          # Upstream binds passwordMaskDelay to `undefined` when
          # HideCompletePassword is "true", which doesn't mean "no delay" — it
          # drops the binding back to Qt's platform default, so how long a
          # typed character stays visible depends on the platform and on the
          # theme config being parsed exactly as the QML expects. That is a
          # bad thing to leave to chance on a login screen.
          #
          # 0 is unambiguous: characters are replaced the instant they're
          # typed, regardless of any config value.
          substituteInPlace "$themeDir/Components/Input.qml" \
            --replace-fail \
              'passwordMaskDelay: config.HideCompletePassword == "true" ? undefined : 1000' \
              'passwordMaskDelay: 0'

          # NOTE: no primaryScreen patch here, on purpose.
          #
          # SDDM does set a `primaryScreen` bool per view (GreeterApp.cpp),
          # and binding the form's visibility to it looked like the clean way
          # to get "form on one display, wallpaper on the other". In practice
          # it hid the form on *both* — under the greeter's kwin_wayland,
          # QGuiApplication::primaryScreen() evidently matches neither view's
          # screen, so the property is false everywhere rather than undefined,
          # and the typeof guard never fires.
          #
          # The form and wallpaper therefore render on every display, which is
          # sddm-astronaut's stock behaviour.

          # The one line that makes the greeter follow the desktop. A dangling
          # symlink is a valid state here and not an error: QSettings on a path
          # that does not resolve simply contributes nothing, and the greeter
          # falls back to upstream's own black_hole colours rather than
          # failing to start. sddm-theme-sync runs before display-manager, so
          # that window is a first boot and nothing else.
          ln -sfn ${sddmRuntimeConfig} \
            "$themeDir/Themes/${sddmEmbeddedTheme}.conf.user"

          mv "$themeDir" "$out/share/sddm/themes/${sddmThemeName}"
        '';
      });

  # Fixed, because there is nothing left for it to vary with. The /etc drop-in
  # that used to rewrite it per palette is gone; see the `themeDropIn` note.
  sddmThemeName = "niri-noctalia";

  # Watches the user's palette *and* wallpaper choices and mirrors both to the
  # login screen. SDDM only reads its config when the greeter starts, so both
  # take effect at the next logout/reboot rather than immediately.
  #
  # `noctalia-resolved` is the manifest Noctalia renders from its colour roles
  # (the `system_palette` user template in home/joshr/niri/noctalia.nix). It is
  # the only palette input here, and that is the point: it describes a custom,
  # builtin, wallpaper-derived or community scheme in the same twenty-six
  # lines, where a palette *name* only ever described the first of those.
  niriStateDir = "/home/${config.local.desktop.primaryUser}/.local/state/niri-theme";
  wallpaperStateFile = "${niriStateDir}/wallpaper";
  resolvedThemeFile = "${niriStateDir}/noctalia-resolved";

  # Leftover state from an abandoned experiment.
  #
  # Earlier versions wrote a kwinoutputconfig.json here so the greeter's
  # kwin_wayland would reproduce the session's display layout. It never
  # worked, and the whole idea is gone — but the file is state under
  # /var/lib, which NixOS does not clean up for code it no longer builds.
  # Left behind it would keep being applied by any kwin-based greeter, so
  # the sync service deletes it unconditionally.
  kwinOutputSddm = "/var/lib/sddm/.config/kwinoutputconfig.json";

  # An /etc drop-in this module no longer writes, and still has to delete.
  #
  # It used to carry `[Theme] Current=niri-<palette>`, rewritten by the sync
  # to select one of the per-palette theme packages. There is one package now
  # and `services.displayManager.sddm.theme` names it declaratively, so the
  # drop-in has nothing left to say — but /etc is only pruned of files NixOS
  # itself declares, and this was never one of them. Left behind on an
  # already-deployed machine it would keep pointing SDDM at a theme directory
  # that is no longer in the store, which is a black login screen rather than
  # a stale one. So the sync deletes it, under both greeters, forever.
  themeDropIn = "/etc/sddm.conf.d/99-niri-active-theme.conf";

  # A solid image in the seed palette's background colour, so sddmWallpaper
  # always exists.
  #
  # This is the leading suspect for the black greeter. The theme config points
  # Background at a fixed runtime path, and that file only appears once the
  # wallpaper switcher has run — on a fresh boot, or before ever picking a
  # wallpaper, it isn't there. sddm-astronaut then feeds a missing image into
  # a blur shader (PartialBlur is on), and a QML scene graph that fails while
  # building an effect chain renders nothing at all rather than falling back
  # to BackgroundColor. That would look exactly like what happened: no error
  # from SDDM, which had already reported the greeter started and connected,
  # and identical behaviour on every display server, because none of them are
  # involved.
  #
  # Unproven — the greeter's own QML warnings were never captured — but it is
  # the only path here that referenced a file that might not exist, it costs
  # a few KB, and it makes the themed greeter safe to retry.
  fallbackWallpaper = pkgs.runCommand "sddm-fallback-wallpaper.png" { } ''
    ${pkgs.imagemagick}/bin/magick -size 1920x1080 "xc:${seedTheme.bg}" "png:$out"
  '';

  syncSddmTheme = pkgs.writeShellScript "sddm-theme-sync" ''
    set -eu

    read_colour() {
      [ -f ${resolvedThemeFile} ] || return 0
      sed -n "s/^$1=\\(#[0-9A-Fa-f]\\{6\\}\\)$/\\1/p" ${resolvedThemeFile} | head -n1 || true
    }

    live_bg=""

    # --- palette ------------------------------------------------------
    ${
      if useAstronaut then
        ''
          bg="$(read_colour bg)"
          bg_alt="$(read_colour bg_alt)"
          fg="$(read_colour fg)"
          fg_dim="$(read_colour fg_dim)"
          accent="$(read_colour accent)"
          accent_dim="$(read_colour accent_dim)"
          err="$(read_colour err)"

          install -d -m 0755 /var/lib/sddm-theme
          conf_tmp="${sddmRuntimeConfig}.tmp"

          # `install` rather than `cp`: the seed is a store file and comes
          # with the store's read-only mode, which would then be the mode the
          # greeter's own config ends up with.
          install -m 0644 ${sddmRuntimeSeed} "$conf_tmp"

          # Substitute the palette, or don't. Either way the seed is published
          # — a greeter reading the build-time colours is a themed greeter,
          # where a `.conf.user` that never appears is upstream's black_hole.
          # All seven or none, so a half-read manifest can't produce a form
          # with the desktop's background and the seed's text on it.
          if [ -n "$bg" ] && [ -n "$bg_alt" ] && [ -n "$fg" ] \
             && [ -n "$fg_dim" ] && [ -n "$accent" ] \
             && [ -n "$accent_dim" ] && [ -n "$err" ]; then
            replace_colour() {
              sed -i "s|^$1=.*|$1=$2|" "$conf_tmp"
            }
            replace_colour HeaderTextColor "$accent"
            replace_colour DateTextColor "$fg"
            replace_colour TimeTextColor "$accent"
            replace_colour FormBackgroundColor "$bg"
            replace_colour BackgroundColor "$bg"
            replace_colour LoginFieldBackgroundColor "$bg_alt"
            replace_colour PasswordFieldBackgroundColor "$bg_alt"
            replace_colour LoginFieldTextColor "$fg"
            replace_colour PasswordFieldTextColor "$fg"
            replace_colour UserIconColor "$accent"
            replace_colour PasswordIconColor "$accent"
            replace_colour PlaceholderTextColor "$fg_dim"
            replace_colour WarningColor "$err"
            replace_colour LoginButtonTextColor "$bg"
            replace_colour LoginButtonBackgroundColor "$accent"
            replace_colour SystemButtonsIconsColor "$accent"
            replace_colour SessionButtonTextColor "$fg"
            replace_colour VirtualKeyboardButtonTextColor "$fg"
            replace_colour DropdownTextColor "$fg"
            replace_colour DropdownSelectedBackgroundColor "$accent_dim"
            replace_colour DropdownBackgroundColor "$bg_alt"
            replace_colour HighlightTextColor "$bg"
            replace_colour HighlightBackgroundColor "$accent"
            replace_colour HighlightBorderColor "$accent"
            replace_colour HoverUserIconColor "$fg"
            replace_colour HoverSystemButtonsIconsColor "$fg"

            live_bg="$bg"
          fi

          mv -f "$conf_tmp" ${sddmRuntimeConfig}
          chmod 0644 ${sddmRuntimeConfig}
        ''
      else
        ""
    }

    # See the themeDropIn note: unmanaged /etc state naming a theme package
    # that no longer exists. Removed under both greeters.
    rm -f "${themeDropIn}"

    # --- wallpaper ----------------------------------------------------
    # The greeter runs as the sddm user and can't read joshr's home, so the
    # image is copied somewhere world-readable. The theme config names a
    # fixed path (see sddmWallpaper), and only the file behind it changes.
    #
    # Converted to PNG rather than copied: the state file may point at a
    # .jpg, and naming a JPEG "wallpaper.png" leaves the format to QML's
    # content sniffing. Converting removes the guess.
    ${lib.optionalString useAstronaut ''
      install -d -m 0755 /var/lib/sddm-theme

      wp="$(cat ${wallpaperStateFile} 2>/dev/null || true)"
      if [ -n "$wp" ] && [ -f "$wp" ]; then
        tmp="${sddmWallpaper}.tmp"
        if ${pkgs.imagemagick}/bin/magick "$wp" -strip "png:$tmp" 2>/dev/null; then
          mv -f "$tmp" "${sddmWallpaper}"
          chmod 0644 "${sddmWallpaper}"
        else
          # Leave the previous image in place rather than blanking the
          # greeter over one unreadable file.
          rm -f "$tmp"
        fi
      elif [ -n "$live_bg" ]; then
        tmp="${sddmWallpaper}.tmp"
        ${pkgs.imagemagick}/bin/magick -size 1920x1080 "xc:$live_bg" "png:$tmp"
        mv -f "$tmp" "${sddmWallpaper}"
        chmod 0644 "${sddmWallpaper}"
      fi

      # Guarantee the file the theme names actually exists. See the
      # fallbackWallpaper note: a missing background is not a cosmetic
      # problem here, it feeds a blur shader and can take the whole greeter
      # down with it. Only used when nothing above produced an image — a
      # first boot, or before a wallpaper has ever been chosen.
      if [ ! -f "${sddmWallpaper}" ]; then
        install -m 0644 "${fallbackWallpaper}" "${sddmWallpaper}"
      fi
    ''}

    # --- clean up the abandoned display sync --------------------------
    # See the kwinOutputSddm note above: /var/lib state that NixOS won't
    # remove on its own, and that a kwin greeter would still obey.
    rm -f "${kwinOutputSddm}"
  '';

  useAstronaut = config.local.sddm.theme == "astronaut";
in
{
  # local.sddm.* lives in its own module so this one can stay a plain config
  # attrset — declaring an option here would mean wrapping everything below
  # in `config = { … }`.
  imports = [ ./options.nix ];

  #nixpkgs.overlays = [
  #   inputs.xwayland-satellite-scale-fixes.overlays.default
  #];
  programs.niri.enable = true;
  
  
  
  # Display manager.
  #
  # `theme` is left unset under local.sddm.theme = "stock", which gives
  # SDDM's own built-in greeter: no external theme package, no QML of ours,
  # no runtime state. That is the configuration to fall back to whenever the
  # login screen misbehaves, because almost nothing in it is our code.
  services.displayManager.sddm = {
    enable = true;
    # Both of these are options rather than edits, because they're the two
    # things worth varying when the greeter misbehaves. See local.sddm.*.
    wayland.enable = config.local.sddm.wayland;
    wayland.compositor = config.local.sddm.compositor;
    package = pkgs.kdePackages.sddm;

    # Cursor for the greeter.
    #
    # SDDM ships no cursor of its own — it reads these and exports
    # XCURSOR_THEME/XCURSOR_SIZE into the greeter, which then looks the name
    # up in the *system* icon path. Without them the greeter inherits
    # whatever the compositor defaults to, which on a bare login screen is
    # frequently nothing at all, and you get an invisible pointer.
    #
    # The session's cursor is set by home.pointerCursor in home/joshr/home.nix
    # and the greeter cannot see it: it runs as the `sddm` user before anyone
    # has logged in. Same names on both sides so the pointer doesn't change
    # shape at login; bibata-cursors is already in environment.systemPackages
    # (modules/nixos/base.nix), which is what puts it on the system icon path.
    settings.Theme = {
      CursorTheme = "Bibata-Modern-Ice";
      CursorSize = 24;
    };

    # Log someone who is already logged in back into the session they left,
    # instead of starting a second one beside it.
    #
    # This is what makes `switch-user` a round trip. SDDM looks for a session
    # of its own for that user in state "online" — exactly what switch-user
    # leaves behind — and answers a successful authentication with
    # UnlockSession followed by ActivateSession on it. Without it you get two
    # niri sessions for one person, each with its own compositor, its own
    # swayidle and its own copy of everything the session starts, and the
    # first one still locked behind them.
    #
    # The UnlockSession half is load-bearing on the session side: swayidle's
    # `unlock` event (home/joshr/niri/lock.nix) takes the lock screen down
    # when it arrives, so the password typed at the greeter is the only one
    # asked for. Nothing else on these machines sends that signal.
    #
    # Set explicitly rather than left to SDDM's default — it defaults to true
    # upstream, but the behaviour is now something this configuration depends
    # on rather than something it happens to inherit.
    settings.Users.ReuseSession = true;
  }
  // lib.optionalAttrs useAstronaut {
    theme = sddmThemeName;
    extraPackages = [ sddmTheme ];
  };

  # The theme has to be on the system as well as in SDDM's own package set —
  # `extraPackages` puts it on the greeter's QML import path, this is what puts
  # the theme directory itself under /run/current-system/sw/share/sddm/themes,
  # which is where SDDM looks the name up.
  #
  # This is the module's one `environment.systemPackages`; the Flatpak store
  # further down lands in it too rather than opening a second one, which the
  # same attribute set cannot have.
  environment.systemPackages =
    lib.optionals useAstronaut [ sddmTheme ]
    # A graphical front end for the Flatpak below, since niri brings no
    # software centre of its own the way Plasma brings this one.
    #
    # Discover rather than GNOME Software because it is the one that comes out
    # looking like the rest of the session: it reads
    # ~/.config/kdeglobals, which the noctalia templates already generate
    # (home/joshr/niri/noctalia-templates/kdeglobals), so it follows a theme
    # switch for the same reason Dolphin does. libadwaita has no equivalent
    # hook. The session also already pays for part of the KDE runtime through
    # polkit-kde-agent, and for the rest of it on a host that sets
    # `local.niri.screenshotEditor = "spectacle"`.
    #
    # Only its Flatpak backend is meaningful here. Discover's PackageKit half
    # manages distribution packages, and on NixOS that is `configuration.nix`
    # and not something an application can be allowed to edit — so the updates
    # page speaks only for the flatpaks, and system updates stay a rebuild.
    ++ [ pkgs.kdePackages.discover ];

  # --- keep the login screen in step with the desktop ---------------------
  #
  # Two things are mirrored, and neither is a theme *name* any more: the
  # palette, substituted into the one theme's `.conf.user`, and the wallpaper,
  # copied to a world-readable path the theme names from the store.
  #
  # The greeter runs as the sddm user before anyone logs in, so it can neither
  # read joshr's home nor see anything under it. Both outputs therefore live in
  # /var/lib/sddm-theme, which is unmanaged state rather than store-managed
  # /etc, and survives activation.
  #
  # It runs under "stock" too, and has to: it removes the /etc drop-in naming
  # a theme package that no longer exists, and the abandoned display-sync
  # file. Both are unmanaged state that would otherwise outlive the code that
  # made them and keep pointing the greeter at things that aren't there.
  systemd.services.sddm-theme-sync = {
    description = "Mirror the desktop palette and wallpaper to the SDDM greeter";
    wantedBy = [ "multi-user.target" ];

    # Must land before the greeter reads its config, or the first boot after
    # a switch still uses the state this is about to fix — which would look
    # exactly like the change not working. Ordering only: if this fails,
    # SDDM still starts.
    before = [ "display-manager.service" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = syncSddmTheme;
    };
  };

  systemd.paths.sddm-theme-sync = lib.mkIf useAstronaut {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = [
      wallpaperStateFile
      resolvedThemeFile
    ];
  };

  # A polkit agent must run in the session for GUI privilege prompts. niri
  # doesn't ship one, so start the KDE agent as a user service tied to the
  # graphical session.
  security.polkit.enable = true;
  systemd.user.services.polkit-kde-agent = {
    description = "polkit KDE agent";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # Audio. Same stack as the Plasma config.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };

 

  # Screen sharing needs a portal backend; the niri module already pulls in
  # xdg-desktop-portal-gnome and sets the routing.
  xdg.portal.enable = true;

  services.flatpak.enable = true;

  # Flathub, added once, because a software centre with no remote configured is
  # an empty window and reads as broken rather than as unconfigured. Discover
  # (in environment.systemPackages above) has no way to add one itself, and
  # `services.flatpak` deliberately configures no remotes.
  #
  # `--if-not-exists` is what keeps this from being a boot-time network call:
  # it returns before fetching anything once the remote is there, so only the
  # first boot after this lands actually talks to dl.flathub.org. That is also
  # why failing is survivable — a first boot with no network leaves the remote
  # unadded and the next one adds it — so nothing else is ordered after this.
  #
  # System-wide rather than `--user`: the flatpaks are installed for the
  # machine, the same way its packages are, and a per-user remote would have to
  # be added again for every account that opened the store.
  systemd.services.flathub-remote = {
    description = "Register the Flathub remote for Flatpak";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo";
    };
  };

  # Mount/unmount removable media from the file manager without a password.
  services.udisks2.enable = true;

  # Unlock the keyring at login (the niri module enables gnome-keyring).
  security.pam.services.sddm.enableGnomeKeyring = true;

  # Lid behavior is hardware policy, not session policy. The USB host sets it
  # because that system may boot on a laptop; fixed desktops importing this
  # module have no lid to configure.
}
