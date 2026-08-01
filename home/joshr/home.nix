{ config, pkgs, inputs, ... }:

{
  # Everything here is desktop-agnostic. The desktop itself — ./plasma.nix or
  # ./niri — is imported by the per-host entrypoint next to this file, so the
  # Plasma and niri variants of a machine can share this base.
  imports = [
    ../common/options.nix
    ../common/shell.nix
    ../common/git.nix
    ./kitty.nix
    ./ranger.nix
    ./vscode.nix
    ./spicetify.nix
    ./firefox.nix
    ./browser.nix
    ./wallhaven.nix
  ];

  # The one place this profile names its user. Everything else that needs a
  # path builds it from `config.home.homeDirectory`, so changing the name
  # here is the whole change — there is no second copy of "joshr" spelled
  # into a path anywhere under home/.
  home.username = "joshr";
  home.homeDirectory = "/home/${config.home.username}";

  # Do not bump this after the initial install; see the Home Manager manual.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true; 


  home.packages = with pkgs; [
    sshfs
    yt-dlp
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

  # Linked file by file rather than as one symlink to the store directory,
  # which is what `recursive` buys: ~/.local/share/wallpapers ends up a real
  # directory whose dotfiles entries are individually symlinked, leaving room
  # beside them for WallhavenFlake/ — twenty files downloaded at activation
  # time, which a read-only store path has nowhere to put. See
  # ./wallhaven.nix, which also handles the one-off removal of the old
  # symlink on the first switch after this change.
  xdg.dataFile."wallpapers" = {
    source = "${inputs.dotfiles}/dot_local/share/wallpapers";
    recursive = true;
  };

  xdg.dataFile."color-schemes/DarkObsidianII.colors".source = ./files/DarkObsidianII.colors;

  # Cursor theme, shared by both the Plasma and niri sessions.
  #
  # This uses nixpkgs' bibata-cursors rather than the copy under
  # dot_icons/ in the dotfiles repo. home-manager's pointerCursor module
  # writes ~/.icons/<name> itself, so linking the dotfiles copy to that same
  # path as well is a conflicting definition — and the module expects a
  # package laid out as ${package}/share/icons/<name>, which the raw
  # dot_icons/ directory isn't.
  #
  # `enable` is spelled out rather than left to be inferred. home-manager used
  # to switch cursor generation on merely because something under
  # `home.pointerCursor` was defined; that is deprecated and warns, since it
  # gives no way to set the theme and leave the generation off.
  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
