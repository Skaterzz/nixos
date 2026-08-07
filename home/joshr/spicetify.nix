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
# generated from niri/themes.nix. Each Niri palette is built as an immutable
# Spicetify package, and the launcher selects the package matching the runtime
# theme recorded in ~/.local/state/niri-theme/current.
let
  themeSet = import ./niri/theme-set.nix {
    inherit lib;
    includeNoctaliaBuiltins = config.local.niri.shell == "noctalia";
  };
  inherit (themeSet) themes;

  currentThemeFile = "${config.home.homeDirectory}/.local/state/niri-theme/current";

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
}
