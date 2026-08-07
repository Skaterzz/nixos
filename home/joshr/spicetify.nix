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
#   * A tiny launcher opts this Spotify process out of Chromium's Local Network
#     Access gate, which an embedded app cannot prompt the user to grant.
#   * theme.js, appended to the Text theme below, polls the service and swaps a
#     single <style> element.
#
# It has to be HTTP rather than a file read because that JavaScript runs in
# Spotify's renderer, where `fetch` on a file:// URL is blocked outright.
# Loopback HTTP is allowed as mixed content, but it is still a local-network
# request; Chromium 142 and newer put both fetches and subresource loads behind
# the Local Network Access permission. Spotify's embedded Chromium does not
# expose that browser permission prompt, so the request is denied before CORS
# or the server's PNA response can help. The launcher below disables exactly
# that feature for this one Spotify process. The service remains bound to
# 127.0.0.1 and serves only the generated stylesheet.
#
# The Spicetify community template is deliberately disabled. It renders
# ~/.config/spicetify/Themes/{Comfy,Colorful}/color.ini and then runs
# `spicetify apply`, but this profile has neither a runtime Spicetify CLI nor a
# mutable Spotify tree for it to patch. `mkSpicetify` did that work at build
# time in the Nix store; the live CSS route above is what changes its colours.
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
    // shell's template; override the custom properties instead of rebuilding
    // Spotify.
    //
    // Two mechanisms, because they recover differently.
    //
    // The <link> is the floor. If the service is up when Spotify starts, the
    // palette is right without waiting for JavaScript to copy the response
    // into a style element. Chromium's Local Network Access gate applies to
    // stylesheet subresources too; the Spotify-only launcher below is what
    // permits this load.
    //
    // The fetch is what makes an *already open* Spotify follow a change. It
    // still uses ordinary CORS and, on older Chromium builds, the Private
    // Network Access preflight described in spicetify.nix. It writes a <style>
    // appended after the link, so when both work the later one wins and they
    // agree anyway.
    (() => {
      const endpoint = "http://127.0.0.1:38471/colors.css";
      const linkId = "noctalia-live-colors-link";
      const styleId = "noctalia-live-colors";

      function installLink() {
        if (document.getElementById(linkId)) return;
        const link = document.createElement("link");
        link.id = linkId;
        link.rel = "stylesheet";
        link.href = endpoint;
        document.head.appendChild(link);
      }

      async function syncNoctaliaColors() {
        try {
          const response = await fetch(endpoint, { cache: "no-store" });
          if (!response.ok) return;
          const css = await response.text();
          let style = document.getElementById(styleId);
          if (!style) {
            style = document.createElement("style");
            style.id = styleId;
            document.head.appendChild(style);
          }
          if (style.textContent !== css) style.textContent = css;
        } catch (_) {
          // The service is absent under the non-Noctalia shell, and the
          // static color.ini baked into this theme remains the fallback.
        }
      }

      function start() {
        installLink();
        syncNoctaliaColors();
        setInterval(syncNoctaliaColors, 2000);
      }

      // Spicetify injects this with `defer`, so the head is parsed by now.
      // The guard is for the case where it is loaded some other way.
      if (document.head) {
        start();
      } else {
        document.addEventListener("DOMContentLoaded", start, { once: true });
      }
    })();
    THEME_JS
  '';

  # Serves exactly one file, to exactly one client, on the loopback interface.
  #
  # On Chromium versions that still use PNA, Spotify's UI is a
  # document on `https://xpui.app.spotify.com`, which is a *public* address
  # space as far as Chromium is concerned, and 127.0.0.1 is the *loopback* one.
  # Private Network Access makes that pairing a preflighted request even for a
  # plain GET: the renderer sends `OPTIONS` carrying
  # `Access-Control-Request-Private-Network: true` and requires the response to
  # answer with `Access-Control-Allow-Private-Network: true` before it will
  # issue the real request at all.
  #
  # `SimpleHTTPRequestHandler` implements GET and HEAD and nothing else, so the
  # preflight was being answered `501 Unsupported method ('OPTIONS')` — and a
  # failed preflight means the GET never happens. The CORS header this already
  # sent was correct and never got the chance to matter. That is why Spotify
  # sat on the palette it was built with on those versions. Newer Chromium
  # builds put the request behind Local Network Access first; spotifyLauncher
  # below handles that separate gate.
  paletteServer = pkgs.writeText "noctalia-spotify-palette-server.py" ''
    from functools import partial
    from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

    class Handler(SimpleHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def end_headers(self):
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Private-Network", "true")
            self.send_header("Cache-Control", "no-store")
            super().end_headers()

        def do_OPTIONS(self):
            self.send_response(204)
            self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "*")
            self.send_header("Access-Control-Max-Age", "86400")
            self.end_headers()

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

  # Spotify 1.2.92 embeds a Chromium new enough to gate public-origin requests
  # to loopback behind Local Network Access permission. xpui is served from
  # https://xpui.app.spotify.com, so both the stylesheet <link> and polling
  # fetch above qualify. A normal Chrome tab can ask the user for that
  # permission; Spotify's embedded browser never surfaces the prompt, leaving
  # the request blocked before it reaches the server.
  #
  # Keep the exception narrower than --disable-web-security: disable only the
  # LNA feature, only for this Spotify process. Older Chromium versions ignore
  # the unknown feature name and continue through the PNA/CORS path supported
  # by paletteServer.
  spotifyLauncher = pkgs.writeShellApplication {
    name = "spotify";
    text = ''
      exec ${lib.getExe spicedSpotify} \
        --disable-features=LocalNetworkAccessChecks \
        "$@"
    '';
  };
in
{
  # The launcher carries the immutable Spicetify package in its closure and is
  # the one `spotify` placed on PATH. It does no palette selection; its only job
  # is the process-local Local Network Access exception above.
  home.packages = [ spotifyLauncher ];

  # spicedSpotify is no longer installed directly, so publish its desktop entry
  # against the launcher and keep the package's icon.
  xdg.desktopEntries.spotify = {
    name = "Spotify";
    genericName = "Music Player";
    comment = "Listen to music and podcasts";
    exec = "${lib.getExe spotifyLauncher} %U";
    icon = "${spicedSpotify}/share/icons/hicolor/256x256/apps/spotify-client.png";
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

  # A plain long-running service rather than a socket unit: it has to be up
  # before Spotify's first request and stay up for the life of the session,
  # and the <link> in theme.js is a page-load subresource with no retry — so
  # there is no first request to activate on and being late is being absent.
  #
  # `Restart = always` with the start limit lifted, because the one way this
  # dies is the port already being held, and the holder is a previous instance
  # of itself on its way out. Giving up after five attempts would leave the
  # session with no palette service until the next login.
  systemd.user.services.noctalia-spotify-palette = lib.mkIf (config.local.niri.shell == "noctalia") {
    Unit = {
      Description = "Expose Noctalia's resolved palette to Spotify";
      After = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${spotifyPaletteDir}";
      ExecStart = "${pkgs.python3}/bin/python ${paletteServer}";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
