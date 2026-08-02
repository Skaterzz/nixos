{ ... }:

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
        {
          type = "audio-in";
          icon-name = "waybar-recording";
          tooltip = true;
          tooltip-icon-size = 24;
        }
      ];

      # Monitor-source capture is normally desktop audio rather than a real
      # microphone. Cava is ignored explicitly as well, matching Waybar's
      # documented privacy-module filtering example.
      ignore-monitor = true;
      ignore = [
        {
          type = "audio-in";
          name = "cava";
        }
      ];
    };
  };

  xdg.dataFile."icons/hicolor/scalable/status/waybar-recording.svg".text = ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
      <circle cx="8" cy="8" r="6" fill="#f44336"/>
    </svg>
  '';
}
