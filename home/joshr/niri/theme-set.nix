{
  lib,
  includeNoctaliaBuiltins ? false,
}:

let
  base = import ./themes.nix { inherit lib; };
  noctaliaBuiltins = import ./noctalia-builtin-themes.nix;
in
base
// {
  themes = base.themes // lib.optionalAttrs includeNoctaliaBuiltins noctaliaBuiltins.themes;
  inherit (noctaliaBuiltins) selections;
}
