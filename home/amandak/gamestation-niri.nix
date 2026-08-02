{ ... }:

# raiden's home profile on the desk, niri session.
#
# joshr's entrypoint for this host, verbatim — the niri desktop, the display
# layout, the office/OBS/content-creation packages and cava in the bar.
# ./home.nix names the account.
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
