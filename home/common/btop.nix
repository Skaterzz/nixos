{ lib, pkgs, ... }:
{
    programs.btop = {
    enable = true;
    package = (pkgs.writeShellScriptBin "btop" ''
    exec env LD_LIBRARY_PATH=/run/opengl-driver/lib ${pkgs.btop-cuda}/bin/btop "$@"
  '');
    settings = {
      color_theme = "tokyo-night";
      theme_background = false;
      update_ms = 100;
    };
  };
}
