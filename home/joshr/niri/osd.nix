{ config, lib, pkgs, niriTheming, ... }:

# swayosd: the on-screen display for volume and brightness.
#
# niri has no OSD of its own — it is a compositor and nothing else — so
# pressing a volume or brightness key used to be silent. The level moved and
# the only way to see where it had landed was to look at waybar, which shows
# volume but not brightness, and only if the bar is on the display you happen
# to be looking at. This is the missing feedback: a pop-up low and centred on
# every output, with an icon, a bar and the number.
#
# Two halves:
#
#   swayosd-server   this unit. A layer-shell overlay window that draws
#                    whatever it is asked to and hides itself again.
#   swayosd-client   a one-shot that asks it to, over the session bus.
#
# The client is never invoked directly from a keybind. `volume` and
# `brightness` in ./scripts.nix make the change themselves and then call `osd`
# to draw the result — see the long note on `osd` there for why the drawing
# and the doing are kept apart.
#
# The libinput backend (caps lock, num lock, scroll lock) is deliberately not
# set up. That half is a *system* service needing udev rules and polkit, it
# reads every input device to do its job, and none of the three keys it
# reports is one this session has anything to say about.
let
  inherit (niriTheming) activeDir;
in
{
  services.swayosd = {
    enable = true;

    # Follows the active theme. `stylePath` becomes `--style <path>` on the
    # server, and the path is the mutable state symlink rather than a store
    # file so a theme switch can reach it — same arrangement as waybar's `-s`
    # and dunst's `configFile`.
    #
    # swayosd reads the stylesheet once, at startup, and has no reload signal,
    # so `theme-apply` restarts this unit. See renderSwayosdCss in
    # ./theming.nix for the sheet itself.
    stylePath = "${activeDir}/swayosd.css";

    # Fraction of the screen height to place the window at: 0.85 is low and
    # centred, which is where an OSD is expected and is clear of the bar at the
    # top. This is swayosd's own default, spelled out so the position is
    # readable from here and doesn't move if upstream's changes.
    topMargin = 0.85;
  };
}
