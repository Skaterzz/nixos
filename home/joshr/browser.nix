{ ... }:

# Which browser is *the* browser.
#
# Firefox, on every host. It is installed and configured by ./firefox.nix.
{
  # For CLI tools that shell out to a browser (gh, glab, xdg-open fallbacks).
  home.sessionVariables.BROWSER = "firefox";
}
