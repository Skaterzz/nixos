{ pkgs, inputs, ... }:

{
  # Everything here is desktop-agnostic. The desktop itself — ./plasma.nix or
  # ./niri — is imported by the per-host entrypoint next to this file, so the
  # Plasma and niri variants of a machine can share this base.
  imports = [
    ../common/options.nix
    ../common/shell.nix
    ./kitty.nix
    ./ranger.nix
    ./vscode.nix
    ./spicetify.nix
    ./firefox.nix
    ./browser.nix
  ];

  home.username = "joshr";
  home.homeDirectory = "/home/joshr";

  # Do not bump this after the initial install; see the Home Manager manual.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    settings.user = {
      name = "Joshua Randall";
      email = "josh@joshrandall.net"; # adjust if this isn't your git identity
    };
    extraConfig = {
      credential = {
         credentialStore = "secretservice";
       };
    };
  };

  services.blueman-applet.enable = false; 

  home.packages = with pkgs; [
    sshfs
  ];

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "tokyo-storm";
      theme_background = false;
      update_ms = 100;
    };
  };
  programs.mangohud = {
    enable = true;
    enableSessionWide = false;
    settings = {
      fps = true;
      frametime = true;
      gpu_stats = true;
      cpu_stats = true;
      gpu_temp = true;
      cpu_temp = true;
    };
  };

  # --- Assets pulled straight from the joshrandall8478/dotfiles repo ---
  # (fonts, custom Plasma themes/look-and-feel, cursor theme, custom icons,
  # and wallpapers referenced by plasma.nix). These are large third-party
  # asset trees that make more sense to reference from source than to
  # hand-transcribe into Nix.
  xdg.dataFile."fonts".source = "${inputs.dotfiles}/dot_local/share/fonts";
  fonts.fontconfig.enable = true;

  xdg.dataFile."plasma/desktoptheme".source =
    "${inputs.dotfiles}/dot_local/share/plasma/desktoptheme";
  xdg.dataFile."plasma/look-and-feel".source =
    "${inputs.dotfiles}/dot_local/share/plasma/look-and-feel";

  xdg.dataFile."icons/j-accent.svg".source = "${inputs.dotfiles}/dot_local/share/icons/j-accent.svg";
  xdg.dataFile."icons/j-contrast.svg".source =
    "${inputs.dotfiles}/dot_local/share/icons/j-contrast.svg";

  xdg.dataFile."wallpapers".source = "${inputs.dotfiles}/dot_local/share/wallpapers";

  xdg.dataFile."color-schemes/DarkObsidianII.colors".source = ./files/DarkObsidianII.colors;

  # Cursor theme, shared by both the Plasma and niri sessions.
  #
  # This uses nixpkgs' bibata-cursors rather than the copy under
  # dot_icons/ in the dotfiles repo. home-manager's pointerCursor module
  # writes ~/.icons/<name> itself, so linking the dotfiles copy to that same
  # path as well is a conflicting definition — and the module expects a
  # package laid out as ${package}/share/icons/<name>, which the raw
  # dot_icons/ directory isn't.
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
