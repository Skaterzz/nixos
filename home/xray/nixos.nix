{ lib, ... }:

{
  imports = [ ../joshr/gamestation-niri.nix ];

  home.username = "xray";

  # Do not inherit the upstream author's Git identity. Authentication remains
  # writable and can be configured with gh/glab after login.
  programs.git.settings.user = lib.mkForce { };

  # Replace links owned by the previous Home Manager configuration. Ordinary
  # files remain protected by the flake's backup policy.
  xdg.configFile = {
    "kitty/kitty.conf".force = true;
    "niri/config.kdl".force = true;
    "noctalia/config.toml".force = true;
    "noctalia/palettes/nord.json".force = true;
  };

  local.niri.workspaceOutput = lib.mkForce "DP-1";
  local.niri.outputs = lib.mkForce [
    {
      name = "DP-1";
      mode = "1920x1080@144.001";
      position = {
        x = 0;
        y = 0;
      };
      focusAtStartup = true;
    }
    {
      name = "DP-2";
      mode = "1920x1080@144.001";
      position = {
        x = 1920;
        y = 0;
      };
    }
  ];
}
