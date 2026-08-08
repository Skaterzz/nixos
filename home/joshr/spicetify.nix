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
    // shell's template; override the custom properties instead of rebuilding
    // Spotify.
    //
    // Two mechanisms, because they fail differently.
    //
    // The <link> is the floor. A stylesheet subresource is fetched in no-cors
    // mode, so it needs no preflight, no CORS headers and no agreement about
    // address spaces — if the service is up when Spotify starts, the palette
    // is right. That is the case that actually matters, because a colour
    // scheme changes far less often than Spotify is launched.
    //
    // The fetch is what makes an *already open* Spotify follow a change. It
    // is the one subject to the Private Network Access preflight described in
    // spicetify.nix, and it writes a <style> appended after the link, so when
    // both work the later one wins and they agree anyway.
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
  # **The preflight is the whole reason this needed fixing.** Spotify's UI is a
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
  # sat on the palette it was built with while every other application in the
  # session followed the shell.
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

  # Which link in the chain is broken.
  #
  # Spotify is the one themed application here whose failure is completely
  # silent: the palette travels through four hops, three of them invisible
  # from a terminal, and every one of them fails by simply leaving Spotify on
  # the scheme it was built with. Two rounds of this were spent inferring the
  # answer from the outside — worth a script rather than a third.
  #
  # It checks the *generation's own* package rather than whatever `spotify`
  # resolves to on PATH, so the xpui it reports on is exactly the one this
  # configuration installs.
  spotifyThemeDoctor = pkgs.writeShellApplication {
    name = "spotify-theme-doctor";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnugrep
      systemd
    ];
    text = ''
      css=${lib.escapeShellArg "${spotifyPaletteDir}/colors.css"}
      url="http://127.0.0.1:38471/colors.css"
      xpui=${lib.escapeShellArg "${spicedSpotify}/share/spotify/xpui"}

      bad=0
      pass() { printf '  ok    %s\n' "$1"; }
      fail() { printf '  FAIL  %s\n' "$1"; bad=$((bad + 1)); }

      echo "1. noctalia renders the palette"
      if [ -s "$css" ]; then
        pass "$css exists and is not empty"
        if grep -q -- '--spice-rgb-main' "$css"; then
          pass "it carries the --spice-rgb-* half of the palette"
        else
          fail "no --spice-rgb-* variables — the template predates the fix for
              the translucent surfaces. Change the colour scheme once, or
              restart noctalia, to re-render it."
        fi
      else
        fail "$css is missing or empty. Noctalia's 'spotify' user template has
              not run: check 'systemctl --user status noctalia' and change the
              colour scheme once."
      fi

      echo "2. the palette service"
      if systemctl --user is-active --quiet noctalia-spotify-palette 2>/dev/null; then
        pass "noctalia-spotify-palette is running"
      else
        fail "noctalia-spotify-palette is not running —
              'systemctl --user status noctalia-spotify-palette' says why.
              Nothing downstream of this can work."
      fi

      echo "3. the transport Spotify's renderer uses"
      if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
        pass "GET $url"
      else
        fail "GET $url failed. The service is not listening on 38471."
      fi

      # The one that was actually broken: Spotify's UI is a document on a
      # public origin reaching a loopback address, which Chromium preflights
      # under Private Network Access. A 501 here means the GET above never
      # gets issued by the browser, however well it works from curl.
      preflight="$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' \
        -X OPTIONS "$url" \
        -H 'Origin: https://xpui.app.spotify.com' \
        -H 'Access-Control-Request-Method: GET' \
        -H 'Access-Control-Request-Private-Network: true' || true)"
      if [ "$preflight" = "204" ]; then
        pass "CORS/Private-Network preflight answered $preflight"
      else
        fail "preflight answered '$preflight', not 204. Chromium will refuse to
              issue the request. A 501 means this generation predates the
              do_OPTIONS handler in home/joshr/spicetify.nix."
      fi

      echo "4. spicetify injected the script"
      if [ -s "$xpui/extensions/theme.js" ] \
        && grep -q noctalia-live-colors "$xpui/extensions/theme.js"; then
        pass "xpui/extensions/theme.js carries the injector"
      else
        fail "xpui/extensions/theme.js is missing or is not ours — 'spicetify
              apply' did not copy the theme's script. inject_theme_js."
      fi
      if grep -q "extensions/theme.js" "$xpui/index.html" 2>/dev/null; then
        pass "index.html loads it"
      else
        fail "index.html has no <script> for extensions/theme.js."
      fi

      echo
      if [ "$bad" -eq 0 ]; then
        echo "All four links are up. If Spotify is still on the wrong palette,"
        echo "it has been running since before one of them came up — restart it."
      else
        echo "$bad check(s) failed; the first FAIL above is the one to fix."
        exit 1
      fi
    '';
  };
in
{
  # Straight into the profile, with the desktop entry the package ships.
  #
  # Both used to be indirected through a `spotify` wrapper that picked a build
  # by palette name, which also meant an `xdg.desktopEntries.spotify` here to
  # point launchers at the wrapper rather than at Spotify. With one build
  # there is nothing to choose and both go away.
  home.packages = [
    spicedSpotify

    # `spotify-theme-doctor` — see the comment on it above. Only where the
    # chain it checks exists.
  ]
  ++ lib.optional (config.local.niri.shell == "noctalia") spotifyThemeDoctor;

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
