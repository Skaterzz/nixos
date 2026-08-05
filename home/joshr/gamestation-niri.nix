{ ... }:

# joshr's home profile on the desk, niri session.
#
# Same base as the Plasma variant (shell, kitty, vscode, packages) with the
# niri desktop in place of plasma.nix. plasma-manager is deliberately not
# imported here — under niri its settings would be inert, and its activation
# script shells out to `plasma-apply-*` tools that aren't in this session.
#
# The display layout lives in ./displays/gamestation.nix, kept separate so
# monitor changes don't mean editing this file.
{
  imports = [
    ./home.nix
    ./desktop-apps.nix
    ./niri
    ./niri/privacy.nix
    ./displays/gamestation.nix
    ./office.nix
    ./obs.nix
    ./content-creation.nix
    ./gaming.nix
    ./kitty.nix
    ./ranger.nix
    ./vscode.nix
    ./spicetify.nix
    ./firefox.nix
    ./browser.nix
    ./wallhaven.nix
    ./emu-hackathon.nix
  ];

  local.waybar.cavaInBar = true;
}
