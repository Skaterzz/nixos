{ config, lib, pkgs, niriTheming, ... }:

# dunst (notifications) and wofi (launcher / menus).
#
# Both are pointed at the active theme directory rather than at a store path,
# so a theme switch reaches them:
#
#   dunst  `configFile`, which the home-manager module turns into
#          `dunst -config <path>`; the switcher restarts the service.
#   wofi   its own `style` config key, re-read on every launch, so no reload
#          is needed at all.
#
# `programs.wofi.style` is deliberately unused: home-manager writes it to a
# store path, which by definition cannot change at runtime.
#
# Note home-manager still writes a ~/.config/dunst/dunstrc of its own — the
# module unconditionally injects `settings.global.icon_path`, so its
# `settings != {}` guard is always true. dunst ignores that file because
# `-config` wins, which is why the rendered dunstrc sets `icon_theme` +
# `enable_recursive_icon_lookup` rather than relying on that `icon_path`.
let
  inherit (niriTheming) activeDir;
in
{
  services.dunst = {
    enable = true;
    configFile = "${activeDir}/dunstrc";
  };

  programs.wofi = {
    enable = true;

    settings = {
      show = "drun";
      prompt = "Search";
      width = 620;
      height = 420;
      lines = 9;
      columns = 1;
      location = "center";
      allow_images = true;
      image_size = 28;
      allow_markup = true;
      insensitive = true;
      no_actions = true;
      gtk_dark = true;
      term = "${pkgs.kitty}/bin/kitty";
      key_expand = "Tab";
      hide_scroll = true;

      # Follows the active theme; wofi re-reads this on every launch.
      style = "${activeDir}/wofi.css";
    };
  };

  # Notification helpers used by scripts and keybinds.
  home.packages = with pkgs; [
    libnotify
    pavucontrol
  ];
}
