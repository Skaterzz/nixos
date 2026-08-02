{ lib, ... }:

# Waybar's native privacy module watches PipeWire for active screen and
# microphone capture. Each item is hidden by Waybar itself while idle, so the
# right-hand bar gains no empty slot when nothing is recording.
#
# The configured GTK icon is deliberately supplied through the standard
# hicolor fallback theme instead of relying on the active icon theme's
# media-record glyph. Papirus renders that glyph as ordinary foreground text;
# this one remains a fixed red recording dot under every niri colour scheme.
{
  programs.waybar.settings.main = {
    # Keep the indicator in the right-hand cluster without replacing the
    # module list owned by waybar.nix. mkBefore makes this the first item in
    # that cluster; it still disappears entirely whenever both capture types
    # are inactive.
    modules-right = lib.mkBefore [ "privacy" ];

    privacy = {
      icon-spacing = 0;
      icon-size = 14;
      transition-duration = 0;

      modules = [
        {
          type = "screenshare";
          icon-name = "waybar-recording";
          tooltip = true;
          tooltip-icon-size = 24;
        }
        #{
         # type = "audio-in";
         # icon-name = "waybar-recording";
         # tooltip = true;
          #tooltip-icon-size = 24;
        #}
      ];

      # Do not count PipeWire monitor sources as microphone recording.
      ignore-monitor = true;
    };
  };

  xdg.dataFile."icons/hicolor/scalable/status/waybar-recording.svg".text = ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
      <circle cx="8" cy="8" r="6" fill="#f44336"/>
    </svg>
  '';
}
