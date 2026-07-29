{ lib, ... }:

# Small set of host-shape options so gamestation and laptop can share the
# same home config. Declared separately from the modules that consume them so
# those don't have to split into options/config blocks.
{
  options.local.plasma.secondaryMonitorPanel = lib.mkEnableOption ''
    the status bar on the second monitor (screen 1).

    On the desk this is the top bar carrying the pager, window list, clock,
    media controls and volume. A single-screen machine has nothing to put it
    on — Plasma would place it on the only display, on top of the panels
    already there
  '';
}
