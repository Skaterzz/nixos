{ ... }:

# joshr's home profile on the desk, niri session.
#
# Same base as the Plasma variant (shell, kitty, vscode, packages) with the
# niri desktop in place of plasma.nix. plasma-manager is deliberately not
# imported here — under niri its settings would be inert, and its activation
# script shells out to `plasma-apply-*` tools that aren't in this session.
{
  imports = [
    ./home.nix
    ./niri
  ];

  # Fixed two-monitor desk layout.
  #
  # DP-3 sits at the origin and DP-2 starts at x=2560, i.e. immediately to its
  # right. Both are top-aligned at y=0, so the 1080p panel lines up with the
  # top of the 1440p one rather than being centred against it — change y on
  # DP-2 to 180 if you'd rather have them centre-aligned.
  #
  # The refresh rates are stated explicitly because a display's preferred
  # mode is frequently not its fastest; without them you can silently end up
  # at 60Hz. Verify the strings against `niri msg outputs` on the machine —
  # they have to match a mode the display actually reports.
  local.niri.outputs = [
    {
      name = "DP-3";
      mode = "2560x1440@180.000";
      position = {
        x = 0;
        y = 0;
      };
      # niri has no "primary" display; this is the nearest thing — the
      # session starts focused here.
      focusAtStartup = true;
    }
    {
      name = "DP-2";
      mode = "1920x1080@100.000";
      position = {
        x = 2560;
        y = 0;
      };
    }
  ];
}
