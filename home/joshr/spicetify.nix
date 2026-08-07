{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

# Port of the existing Spicetify setup from the dotfiles repository.
#
# The Text theme's CSS comes from the dotfiles; its colours come from
# Noctalia, at runtime.
#
# One Spotify, not one per palette
# --------------------------------
# A Spicetify build is immutable — `mkSpicetify` patches Spotify's xpui bundle
# in a derivation, so the colours are baked in. The way that was reconciled
# with a runtime theme switcher was to build *every* palette: thirty-odd
# Spotify packages, and a launcher that read `~/.local/state/niri-theme/current`
# and `exec`d whichever one matched.
#
# Under Noctalia that cannot work, and it did not. The palette can be derived
# from a wallpaper or downloaded from api.noctalia.dev, so there is no Nix
# build for it and the shell writes `noctalia-live` to `current` — a name no
# arm of that case ever matched, so the launcher fell through to the default
# every single time. Spotify was pinned to the palette in themes.nix no matter
# what the desktop was wearing, which is exactly the symptom that prompted
# this.
#
# So: one build, and the colours arrive over the wire instead.
#
#   * Noctalia's `spotify` user template renders the live palette to
#     ~/.local/state/noctalia-spotify/colors.css as `--spice-*` custom
#     properties, on every colour-scheme change (see niri/noctalia.nix).
#   * A loopback-only HTTP service exposes that one file.
#   * theme.js, appended to the Text theme below, polls it and swaps a single
#     <style> element.
#
# It has to be HTTP rather than a file read because that JavaScript runs in
# Spotify's renderer, where `fetch` on a file:// URL is blocked outright. A
# 127.0.0.1 origin is exempt from mixed-content blocking by specification, so
# the request goes through unmodified.
#
# The Spicetify community template is enabled too (`spicetify` in
# `community_ids`) and renders the same palette into
# ~/.config/spicetify/Themes/{Comfy,Colorful}/color.ini. Its post-hook runs
# `spicetify apply`, which is inert here — that command patches a mutable
# Spotify install, and this one is a read-only store path. The files it writes
# are what a Spicetify CLI setup would consume; nothing on this machine reads
# them.
let
  themeSet = import ./niri/themes.nix { inherit lib; };
  inherit (themeSet) themes;

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

  # Every palette is still rendered into color.ini, and only one of them is
  # ever selected. That is not waste: Spicetify wants a `[scheme]` section to
  # exist for the name it is built with, and shipping the whole set keeps
  # `colorScheme` below a one-word change rather than a new render. What the
  # scheme actually decides is the two seconds between the window appearing
  # and the live CSS landing on it.
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

    // Noctalia derives palettes from a wallpaper or a downloaded community
    // scheme at runtime, long after this immutable theme was built. A tiny
    // loopback-only service exposes the resolved variables written by the
    // shell's template; replace one style element instead of rebuilding
    // Spotify.
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
          // The service is absent under the non-Noctalia shell; the static
          // color.ini above remains the fallback.
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

  spicedSpotify = inputs.spicetify-nix.lib.mkSpicetify pkgs {
    theme = {
      name = "text";
      src = textTheme;
      injectCss = true;
      injectThemeJs = true;
      replaceColors = true;
      overwriteAssets = false;
    };

    # What the window wears for the moment before theme.js has fetched the
    # live palette, and on a machine where the shell has never run.
    colorScheme = themeSet.default;

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
in
{
  # Straight into the profile, with the desktop entry the package ships.
  #
  # Both used to be indirected through a `spotify` wrapper that picked a build
  # by palette name, which also meant an `xdg.desktopEntries.spotify` here to
  # point launchers at the wrapper rather than at Spotify. With one build
  # there is nothing to choose and both go away.
  home.packages = [ spicedSpotify ];

  # Serves exactly one file, to exactly one client, on the loopback interface.
  #
  # `Restart = on-failure` rather than a socket unit because it has to be up
  # before Spotify's first poll and stay up for the life of the session; there
  # is no first request to activate on.
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
