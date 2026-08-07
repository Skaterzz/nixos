{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

# Port of the existing Spicetify setup from the dotfiles repository.
#
# The Text theme's CSS remains sourced from dotfiles, while color.ini is
# generated from niri/themes.nix. Finite Niri palettes remain immutable
# packages; when Noctalia owns the shell, its resolved live palette is layered
# over Text at runtime so wallpaper/community schemes work too.
let
  themeSet = import ./niri/theme-set.nix {
    inherit lib;
    includeNoctaliaBuiltins = config.local.niri.shell == "noctalia";
  };
  inherit (themeSet) themes;

  currentThemeFile = "${config.home.homeDirectory}/.local/state/niri-theme/current";
  spotifyPaletteDir = "${config.home.homeDirectory}/.local/state/noctalia-spotify";

  stripHash = lib.removePrefix "#";

  renderScheme = name: theme: ''
    [${name}]
    accent             = ${stripHash theme.accent}
    accent-active      = ${stripHash theme.accent}
    accent-inactive    = ${stripHash theme.bgAlt}
    banner             = ${stripHash theme.accent}
    border-active      = ${stripHash theme.accent}
    border-inactive    = ${stripHash theme.border}
    header             = ${stripHash theme.bgAlt}
    highlight          = ${stripHash theme.bgAlt}
    main               = ${stripHash theme.bg}
    notification       = ${stripHash theme.accent}
    notification-error = ${stripHash theme.err}
    subtext            = ${stripHash theme.fgDim}
    text               = ${stripHash theme.fg}
  '';

  generatedColorIni = lib.concatStringsSep "\n" (lib.mapAttrsToList renderScheme themes);

  textThemeSource = inputs.dotfiles + "/dot_config/private_spicetify/private_Themes/text";

  textTheme = pkgs.runCommand "spicetify-text-niri" { } ''
    mkdir -p "$out"
    cp -R --no-preserve=mode ${textThemeSource}/. "$out/"
    chmod -R u+w "$out"

    cat > "$out/color.ini" <<'COLOR_INI'
    ${generatedColorIni}
    COLOR_INI

    cat >> "$out/theme.js" <<'THEME_JS'

    // Noctalia can derive palettes from a wallpaper or a downloaded community
    // scheme at runtime, long after this immutable theme was built. A tiny
    // loopback-only service exposes the resolved variables written by the
    // shell hook; replace one style element instead of rebuilding Spotify.
    (() => {
      const endpoint = "http://127.0.0.1:38471/colors.css";
      const id = "noctalia-live-colors";

      async function syncNoctaliaColors() {
        try {
          const response = await fetch(endpoint, { cache: "no-store" });
          if (!response.ok) return;
          const css = await response.text();
          let style = document.getElementById(id);
          if (!style) {
            style = document.createElement("style");
            style.id = id;
            document.head.appendChild(style);
          }
          if (style.textContent !== css) style.textContent = css;
        } catch (_) {
          // The service is absent under the non-Noctalia shell; static
          // color.ini remains the fallback.
        }
      }

      syncNoctaliaColors();
      setInterval(syncNoctaliaColors, 2000);
    })();
    THEME_JS
  '';

  paletteServer = pkgs.writeText "noctalia-spotify-palette-server.py" ''
    from functools import partial
    from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

    class Handler(SimpleHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def end_headers(self):
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Cache-Control", "no-store")
            super().end_headers()

    handler = partial(Handler, directory=${builtins.toJSON spotifyPaletteDir})
    ThreadingHTTPServer(("127.0.0.1", 38471), handler).serve_forever()
  '';

  marketplaceSource =
    inputs.dotfiles + "/dot_config/private_spicetify/private_CustomApps/marketplace";

  waveVisualizerArchive =
    inputs.dotfiles + "/dot_config/private_spicetify/private_CustomApps/wave-visualizer.zip";

  waveVisualizer =
    pkgs.runCommand "spicetify-wave-visualizer"
      {
        nativeBuildInputs = with pkgs; [
          coreutils
          findutils
          unzip
        ];
      }
      ''
        mkdir -p "$out"
        temporary="$(mktemp -d)"
        unzip -q ${waveVisualizerArchive} -d "$temporary"

        count="$(find "$temporary" -mindepth 1 -maxdepth 1 -printf x | wc -c)"
        first="$(find "$temporary" -mindepth 1 -maxdepth 1 -print -quit)"

        if [ "$count" -eq 1 ] && [ -d "$first" ]; then
          cp -R "$first"/. "$out/"
        else
          cp -R "$temporary"/. "$out/"
        fi
      '';

  spicetifyConfig = colorScheme: {
    theme = {
      name = "text";
      src = textTheme;
      injectCss = true;
      injectThemeJs = true;
      replaceColors = true;
      overwriteAssets = false;
    };

    inherit colorScheme;

    alwaysEnableDevTools = false;
    experimentalFeatures = true;

    enabledCustomApps = [
      {
        name = "marketplace";
        src = marketplaceSource;
      }
      {
        name = "wave-visualizer";
        src = waveVisualizer;
      }
    ];
  };

  # The Spicetify output is immutable, so runtime switching is implemented by
  # selecting among prebuilt variants rather than trying to rewrite the Nix
  # store after theme-apply runs.
  spicedSpotifys = lib.mapAttrs (
    name: _: inputs.spicetify-nix.lib.mkSpicetify pkgs (spicetifyConfig name)
  ) themes;

  spotifyCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: package: ''
      ${name}) target="${package}/bin/spotify" ;;
    '') spicedSpotifys
  );

  defaultSpotify = spicedSpotifys.${themeSet.default};

  spotifyLauncher = pkgs.writeShellApplication {
    name = "spotify";
    text = ''
      current="$(cat "${currentThemeFile}" 2>/dev/null || true)"
      target=""

      case "$current" in
      ${spotifyCases}
        *) target="${defaultSpotify}/bin/spotify" ;;
      esac

      exec "$target" "$@"
    '';
  };

  # A changed Niri theme should also repaint an already-running Spotify. The
  # launcher itself handles the correct package on normal startup; this helper
  # only restarts Spotify when a Spotify process was already running.
  spotifyThemeSync = pkgs.writeShellApplication {
    name = "spotify-theme-sync";
    runtimeInputs = with pkgs; [
      coreutils
      procps
      systemd
    ];
    text = ''
      if ! pgrep -x spotify >/dev/null; then
        exit 0
      fi

      pkill -TERM -x spotify || true

      for _ in $(seq 1 50); do
        if ! pgrep -x spotify >/dev/null; then
          break
        fi
        sleep 0.1
      done

      unit="spotify-theme-$(date +%s%N)"
      systemd-run --user --quiet --collect \
        --unit="$unit" \
        "${spotifyLauncher}/bin/spotify"
    '';
  };
in
{
  home.packages = [ spotifyLauncher ];

  # The selected immutable package is not added directly to home.packages, so
  # provide a desktop entry that targets the theme-aware launcher.
  xdg.desktopEntries.spotify = {
    name = "Spotify";
    genericName = "Music Player";
    comment = "Listen to music and podcasts";
    exec = "${spotifyLauncher}/bin/spotify %U";
    icon = "${defaultSpotify}/share/icons/hicolor/256x256/apps/spotify-client.png";
    terminal = false;
    type = "Application";
    categories = [
      "Audio"
      "Music"
      "Player"
      "AudioVideo"
    ];
    mimeType = [ "x-scheme-handler/spotify" ];
    settings.StartupWMClass = "spotify";
  };

  systemd.user.services.spotify-theme-sync = {
    Unit = {
      Description = "Restart Spotify with the active Niri theme";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${spotifyThemeSync}/bin/spotify-theme-sync";
    };
  };

  systemd.user.paths.spotify-theme-sync = {
    Unit.Description = "Watch the active Niri theme for Spotify";
    Path.PathChanged = currentThemeFile;
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.noctalia-spotify-palette = lib.mkIf (config.local.niri.shell == "noctalia") {
    Unit = {
      Description = "Expose Noctalia's resolved palette to Spotify";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${spotifyPaletteDir}";
      ExecStart = "${pkgs.python3}/bin/python ${paletteServer}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
