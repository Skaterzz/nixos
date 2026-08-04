{ ... }:

# joshr's home profile on the desk, Plasma session: multi-monitor, so the
# second-screen status bar is wanted.
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

  local.plasma.secondaryMonitorPanel = true;
}
