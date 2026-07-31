{ config, lib, pkgs, niriTheming, niriScripts, ... }:

# Top bar.
#
#   left    workspaces + focused window title
#   centre  clock and date
#   right   tray, audio, network, battery, session menu
#
# Colours are pulled in with a GTK CSS @import from the active theme
# directory, so `theme-apply` recolours the bar without home-manager
# rebuilding anything. Layout and geometry stay here.
let
  inherit (niriTheming) activeDir;
in
{
  programs.waybar = {
    enable = true;

    # niri spawns waybar itself (spawn-at-startup), so the systemd unit would
    # be a second copy.
    systemd.enable = false;

    settings.main = {
      layer = "top";
      position = "top";
      height = 34;
      spacing = 6;
      margin-top = 6;
      margin-left = 10;
      margin-right = 10;

      modules-left = [
        "niri/workspaces"
        "niri/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "pulseaudio"
        "network"
        "battery"
        "custom/session"
      ];

      "niri/workspaces" = {
        format = "{value}";
        all-outputs = false;
        # Named workspaces "1".."5" come from the niri config.
        format-icons = {
          active = "";
          default = "";
        };
        on-click = "activate";
      };

      "niri/window" = {
        format = "{title}";
        max-length = 70;
        separate-outputs = true;
        rewrite = {
          "(.*) — Mozilla Firefox" = "󰈹  $1";
          "(.*) - Vivaldi" = "󰖟  $1";
          "(.*) - Visual Studio Code" = "󰨞  $1";
          "^kitty$" = "  Terminal";
          "^$" = "  Desktop";
        };
      };

      clock = {
        format = "  {:%H:%M}   {:%a, %b %d}";
        format-alt = "  {:%H:%M:%S}   {:%A, %d %B %Y}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "month";
          on-scroll = 1;
          format = {
            months = "<span color='#c8f5c8'><b>{}</b></span>";
            days = "<span color='#5c7a5c'>{}</span>";
            weekdays = "<span color='#39ff14'><b>{}</b></span>";
            today = "<span color='#39ff14'><b><u>{}</u></b></span>";
          };
        };
        actions = {
          on-click-right = "mode";
          on-scroll-up = "shift_up";
          on-scroll-down = "shift_down";
        };
      };

      tray = {
        icon-size = 16;
        spacing = 10;
        show-passive-items = true;
      };

      pulseaudio = {
        format = "{icon}  {volume}%";
        format-muted = "󰝟  muted";
        format-icons.default = [ "󰕿" "󰖀" "󰕾" ];
        scroll-step = 5;
        on-click = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        on-click-right = "${pkgs.pavucontrol}/bin/pavucontrol";
        tooltip-format = "{desc}";
      };

      network = {
        format-wifi = "  {signalStrength}%";
        format-ethernet = "󰈀  wired";
        format-linked = "󰈀  {ifname}";
        format-disconnected = "󰖪  offline";
        tooltip-format-wifi = "{essid}  ({signalStrength}%)\n{ipaddr}";
        tooltip-format-ethernet = "{ifname}\n{ipaddr}";
        on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
      };

      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon}  {capacity}%";
        format-charging = "󰂄  {capacity}%";
        format-plugged = "󰚥  {capacity}%";
        format-icons = [ "󰁺" "󰁼" "󰁾" "󰂀" "󰂂" ];
        tooltip-format = "{timeTo}";
      };

      "custom/session" = {
        format = "⏻";
        tooltip = false;
        on-click = lib.getExe niriScripts.sessionMenu;
      };
    };

    style = ''
      /* Palette comes from the active theme; see home/joshr/niri/theming.nix.
         theme-apply repoints that symlink and sends waybar SIGUSR2. */
      @import url("file://${activeDir}/waybar.css");

      * {
        font-family: "FiraCode Nerd Font", "Noto Sans", sans-serif;
        font-size: 13px;
        font-weight: 500;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background: transparent;
        color: @fg;
      }

      /* Each group is its own floating pill rather than one long bar. */
      .modules-left,
      .modules-center,
      .modules-right {
        background-color: alpha(@bg, 0.88);
        border: 1px solid alpha(@accent-dim, 0.55);
        border-radius: 12px;
        padding: 0 6px;
      }

      #workspaces {
        padding: 0 2px;
      }

      #workspaces button {
        padding: 0 9px;
        margin: 4px 2px;
        color: @fg-dim;
        background: transparent;
        border-radius: 8px;
        transition: background-color 160ms ease, color 160ms ease;
      }

      #workspaces button:hover {
        background-color: alpha(@accent, 0.15);
        color: @fg;
        /* waybar's default hover adds a box-shadow; suppress it. */
        box-shadow: none;
        text-shadow: none;
      }

      #workspaces button.active {
        background-color: @accent;
        color: @bg;
        font-weight: 700;
      }

      #workspaces button.urgent {
        background-color: @err;
        color: @bg;
      }

      #window {
        padding: 0 10px;
        color: @fg;
      }

      /* Empty title: collapse the padding so the pill doesn't float alone. */
      window#waybar.empty #window {
        padding: 0;
        margin: 0;
        background: transparent;
      }

      #clock {
        padding: 0 14px;
        color: @accent;
        font-weight: 700;
      }

      #tray,
      #pulseaudio,
      #network,
      #battery,
      #custom-session {
        padding: 0 10px;
        margin: 4px 1px;
        border-radius: 8px;
        color: @fg;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: @err;
        border-radius: 8px;
      }

      #pulseaudio:hover,
      #network:hover,
      #battery:hover {
        background-color: alpha(@accent, 0.14);
      }

      #pulseaudio.muted {
        color: @fg-dim;
      }

      #network.disconnected {
        color: @err;
      }

      #battery.warning:not(.charging) {
        color: @warn;
      }

      #battery.critical:not(.charging) {
        color: @bg;
        background-color: @err;
      }

      #custom-session {
        color: @accent;
        font-size: 15px;
        padding: 0 12px;
      }

      #custom-session:hover {
        background-color: @err;
        color: @bg;
      }

      tooltip {
        background-color: @bg;
        border: 1px solid @accent-dim;
        border-radius: 10px;
      }

      tooltip label {
        color: @fg;
        padding: 4px;
      }
    '';
  };
}
