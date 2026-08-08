{ ... }:

# amandak's home profile on the desk, niri session.
#
# joshr's entrypoint for this host, verbatim — the niri desktop, the display
# layout, the office/OBS/content-creation packages and cava in the bar.
# ./home.nix names the account.
#
# That entrypoint is where `local.niri.shell = "noctalia"` is set, so importing
# it is what gives this account the same one-process shell joshr's session
# runs: the same bar, launcher, notifications, OSD, lock screen and wallpaper
# handling, out of the same generated ~/.config/noctalia/config.toml.
#
# The session's own theme state lives under this account's home like any other
# (~/.local/state/niri-theme), so switching themes here changes this session
# and nothing else. The greeter and the boot menu follow
# `local.desktop.primaryUser` — joshr — not whoever last picked a theme.
{
  imports = [
    ./home.nix
    ../joshr/gamestation-niri.nix
  ];
}
