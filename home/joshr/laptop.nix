{ ... }:

# joshr's home profile on the laptop, Plasma session. The same as the desk
# apart from the panels and the lid: only the built-in display, so the
# screen-1 status bar is left off (`local.plasma.secondaryMonitorPanel`
# defaults to false).
#
# The dock and the screen-0 status bar are still both present, since those
# live on the primary display either way.
{
  imports = [
    ./home.nix
    ./plasma.nix
    ./kitty.nix
    ./ranger.nix
    ./vscode.nix
    ./spicetify.nix
    ./firefox.nix
    ./browser.nix
    ./wallhaven.nix
  ];

  # The lid, Plasma's copy of it.
  #
  # modules/nixos/laptop.nix sets this at the logind level, and on this host
  # that is not enough on its own: powerdevil takes a *block* inhibitor on
  # handle-lid-switch as soon as the session starts ("KDE handles power
  # events") and handles the lid itself, so logind's HandleLidSwitch* keys
  # never fire while Plasma is running. They still cover the greeter and a
  # bare TTY, so both halves are worth having — and worth agreeing.
  #
  # The same three cases, in powerdevil's vocabulary:
  #
  #   on battery              sleep         (logind: suspend)
  #   on mains, not docked    lockScreen    (logind: lock)
  #   docked                  nothing       (logind: ignore)
  #
  # Docked is the odd one out, because powerdevil has no docked profile — it
  # has a per-profile "don't take the lid action when an external monitor is
  # connected", which is the same rule written from the other side. It's set
  # on every profile because logind's docked case wins over the power source
  # too, so "docked does nothing" has to hold on battery as well.
  #
  # lowBattery is only reachable on battery, so its lid action matches that
  # profile's. It is stated rather than left to KDE's default so all three
  # profiles say what they do in one place.
  #
  # Sleeping still locks: kscreenlocker.lockOnResume is on in ./plasma.nix,
  # the way swayidle's before-sleep covers it under niri.
  #
  # Here rather than in plasma.nix because that file is shared with the desk,
  # which has no lid — the same reason the logind half lives in
  # modules/nixos/laptop.nix rather than in niri.nix.
  programs.plasma.powerdevil = {
    AC = {
      whenLaptopLidClosed = "lockScreen";
      inhibitLidActionWhenExternalMonitorConnected = true;
    };
    battery = {
      whenLaptopLidClosed = "sleep";
      inhibitLidActionWhenExternalMonitorConnected = true;
    };
    lowBattery = {
      whenLaptopLidClosed = "sleep";
      inhibitLidActionWhenExternalMonitorConnected = true;
    };
  };
}
