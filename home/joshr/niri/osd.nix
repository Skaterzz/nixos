{ config, lib, pkgs, niriTheming, niriScripts, ... }:

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
#
# The third thing with a pop-up is the power profile, and it is the one that
# needs a service of its own — see `power-profile-osd` below.
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

  # The power profile's pop-up, which is a watcher rather than a keybind.
  #
  # Volume and brightness are drawn by the scripts that change them, because
  # the keys are the only thing that changes them. The profile has several
  # routes — the bar, `powerprofilesctl`, a `launch` hold a game takes, the
  # daemon dropping out of performance by itself — and the point of showing it
  # is to see the ones that weren't you. So the display hangs off the daemon's
  # own PropertiesChanged signal instead; see `power-profile-osd` in
  # ./scripts.nix for how it listens and why it reads the profile back rather
  # than parsing it out of the signal.
  #
  # Nothing conditional around it. On a host with no power-profiles-daemon the
  # signal never arrives and the loop simply blocks forever, at the cost of one
  # idle process — the same shape as the bar's widget, which hides itself when
  # nothing answers. The daemon is on for every graphical host anyway
  # (modules/nixos/desktop.nix).
  #
  # `Restart = "always"` and not `on-failure`: the failure worth surviving is
  # gdbus exiting *cleanly* when the bus goes away, which leaves the unit
  # inactive and the pop-up silently gone for the rest of the session.
  systemd.user.services.power-profile-osd = {
    Unit = {
      Description = "Show an OSD when the power profile changes";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${niriScripts.powerProfileOsd}/bin/power-profile-osd";
      Restart = "always";
      RestartSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
