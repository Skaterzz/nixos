{ config, lib, pkgs, niriTheming, ... }:

# dunst (notifications) and wofi (launcher / menus).
#
# dunst has no include mechanism, so the whole dunstrc is rendered per theme
# in theming.nix and selected here through `configFile`, which the
# home-manager module turns into `dunst -config <path>`.
#
# Note that home-manager still writes a ~/.config/dunst/dunstrc of its own —
# the module unconditionally injects `settings.global.icon_path`, so its
# `settings != {}` guard is always true. dunst ignores that file because
# `-config` takes precedence, which is why the rendered dunstrc sets
# `icon_theme` + `enable_recursive_icon_lookup` instead of relying on the
# `icon_path` home-manager computes.
#
# wofi uses GTK CSS, so it can @import the active palette like waybar does,
# and it re-reads its stylesheet on every launch — no reload needed.
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
    };

    style = ''
      /* Palette from the active theme; see home/joshr/niri/theming.nix. */
      @import url("file://${activeDir}/wofi.css");

      * {
        font-family: "FiraCode Nerd Font", "Noto Sans", sans-serif;
        font-size: 14px;
      }

      window {
        background-color: alpha(@bg, 0.96);
        border: 1px solid @accent;
        border-radius: 14px;
      }

      #outer-box {
        padding: 14px;
      }

      #input {
        background-color: @bg-alt;
        color: @fg;
        border: 1px solid @border;
        border-radius: 10px;
        padding: 9px 12px;
        margin-bottom: 12px;
      }

      #input:focus {
        border-color: @accent;
      }

      #input image {
        color: @accent;
      }

      #scroll {
        margin: 0;
      }

      #inner-box {
        background-color: transparent;
      }

      #entry {
        padding: 8px 10px;
        border-radius: 9px;
        color: @fg;
        background-color: transparent;
      }

      #entry:selected {
        background-color: @accent;
        color: @bg;
        font-weight: 700;
      }

      #entry image {
        margin-right: 10px;
      }

      #text {
        color: inherit;
      }

      #text:selected {
        color: @bg;
      }

      /* Fuzzy-match highlight inside a row. */
      #entry #text mark {
        background-color: transparent;
        color: @accent;
        font-weight: 700;
      }

      #entry:selected #text mark {
        color: @bg;
        text-decoration: underline;
      }
    '';
  };

  # Notification helpers used by scripts and keybinds.
  home.packages = with pkgs; [
    libnotify
    pavucontrol
  ];
}
