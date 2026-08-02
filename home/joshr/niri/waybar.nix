{ config, lib, pkgs, niriTheming, niriScripts, ... }:

# Top bar.
#
#   left    workspaces + focused window title
#   centre  clock and date
#   right   tray, nowplaying, audio, network, battery, session menu
#
# Theming: waybar is started with `-s <active theme>/waybar.css` and the
# switcher restarts it, so a theme change swaps the whole stylesheet. The
# `programs.waybar.style` option is deliberately not used — home-manager
# would write it to a store path that can't change at runtime.
let
  inherit (niriTheming) activeDir;

  cavaEntry =
    if config.local.waybar.cavaInBar then
      "custom/cava"
    else
      "";
in
{
  programs.waybar = {
    enable = true;

    # Run as a user service rather than niri's spawn-at-startup, so the theme
    # switcher can `systemctl --user restart waybar` and be certain the
    # stylesheet is re-read. (SIGUSR2 alone did not reliably repaint.)
    systemd.enable = true;

    # A list since home-manager renamed the singular `systemd.target`, which
    # now warns. Named rather than left to `wayland.systemd.target`'s default,
    # matching swayidle and cliphist: niri starts the session and everything
    # graphical in this config hangs off graphical-session.target.
    systemd.targets = [ "graphical-session.target" ];

    settings.main = {
      layer = "top";
      position = "top";
      height = 34;
      spacing = 6;
      margin-top = 6;
      margin-left = 10;
      margin-right = 10;

      modules-left = [
        "custom/user"
        "niri/workspaces"
        "niri/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        cavaEntry
        "mpris"
        "tray"
        "pulseaudio"
        "bluetooth"
        "network"
        "battery"
        "custom/idle-inhibitor"
        "custom/lock"
        "custom/session"
      ];

      # Who the session belongs to, first thing on the bar.
      #
      # Static text, no `exec`: home-manager already knows the name, so it is
      # baked in at build time rather than shelling out to `whoami` on an
      # interval to print a string that cannot change while the bar is
      # running. custom/lock and custom/session at the bottom of this file
      # are the same shape — a custom module with no exec just draws its
      # format string.
      #
      # Reading it from `config.home.username` rather than writing "joshr"
      # is what makes it survive a second user: their generation renders
      # their own name with nothing to edit.
      "custom/user" = {
        format = "󰀄  ${config.home.username}";
        tooltip = false;
      };

      "niri/workspaces" = {
        format = "{value}";
        all-outputs = false;
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

      # Eight bars of whatever is coming out of the speakers, sitting just
      # left of the track name. Gone entirely when it's quiet — the script
      # prints an empty line and waybar hides a custom module with no text —
      # so the bar is unchanged from before whenever nothing is playing.
      #
      # Continuous, not polled: the script prints one frame per line and
      # waybar takes each line as the new value. Deliberately no `interval`,
      # which would switch waybar to running the script once per tick and
      # reading a single value instead. `restart-interval` is the resilience:
      # if cava exits — an audio device going away, pipewire restarting — it
      # gets started again rather than leaving a dead slot.
      #
      # See cavaBar in scripts.nix for the cava config and the glyph mapping.
      "custom/cava" = {
        format = "{}";
        exec = lib.getExe niriScripts.cavaBar;
        restart-interval = 5;
        tooltip = false;
      };

      mpris = {
        player = "playerctld";

        format = "{player_icon} {dynamic}";
        format-paused = "{status_icon} {dynamic}";
        format-stopped = "";

        tooltip = true;
        tooltip-format = ''
          {player_icon}  {title}
          {artist}
          {album}
          {position} / {length}
        '';

        title-len = 20;
        artist-len = 20;
        album-len = 20;
        dynamic-len = 30;

        dynamic-order = [
          "title"
          "artist"
        ];

        dynamic-importance-order = [
          "title"
          "artist"
        ];

        dynamic-separator = " • ";

        player-icons = {
          default = "󰎆";
          spotify = "";
          firefox = "󰈹";
          chromium = "";
          chrome = "";
          mpv = "";
          vlc = "󰕼";
        };

        status-icons = {
          playing = "";
          paused = "";
          stopped = "";
        };

        # Left click: play/pause
        on-click = "playerctl play-pause";

        # Middle click: previous track
        on-click-middle = "playerctl previous";

        # Right click: next track
        on-click-right = "playerctl next";

        # Scroll over the widget to change volume
        on-scroll-up = "playerctl volume 0.01+";
        on-scroll-down = "playerctl volume 0.01-";
      };
      clock = {
        # One replacement field only. waybar passes the clock module a single
        # time argument, so a format string with two `{:...}` placeholders
        # refers to an argument that doesn't exist and the module renders
        # nothing at all — which is why the centre of the bar was empty.
        # Everything therefore goes through one strftime.
        #
        # 12-hour, month before day. `%I` keeps the leading zero ("07:30 PM")
        # rather than `%-I` ("7:30 PM") on purpose: waybar formats through
        # libfmt/date.h, not glibc's strftime, and the `%-` no-padding
        # modifier is a glibc extension neither of those implements — it
        # comes out as a literal "-I", or throws the whole format away.
        format = "  {:%I:%M %p      %a, %b %d}";
        format-alt = "  {:%I:%M %p      %A, %B %d, %Y}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "month";
          on-scroll = 1;
          format = {
            months = "<b>{}</b>";
            today = "<b><u>{}</u></b>";
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

        # nm-applet is spawned for its connection menu, but its tray icon
        # duplicates the `network` module two slots over. Hide the icon and
        # keep the applet — ignore-list matches any of the item's bus name,
        # category, icon name, id or title as a substring.
        ignore-list = [
         "nm-applet"
         "blueman-applet"
        ];
      };

      # Click and scroll both go through the same `volume` script the media
      # keys use, so every route to the volume raises the OSD and none of them
      # can drift from the others.
      #
      # That replaces the module's built-in scrolling rather than adding to it:
      # `Pulseaudio::handleScroll` hands off to the generic handler as soon as
      # either `on-scroll-*` is a string, and never reaches its own code. So
      # `scroll-step` is gone too — it would look like it still set the step,
      # and the 1 that does is the argument below.
      pulseaudio = {
        format = "{icon}  {volume}%";
        format-muted = "󰝟  muted";
        format-icons.default = [ "󰕿" "󰖀" "󰕾" ];
        on-click = "${lib.getExe niriScripts.volume} mute";
        on-click-right = "${pkgs.pavucontrol}/bin/pavucontrol";
        on-scroll-up = "${lib.getExe niriScripts.volume} up 1";
        on-scroll-down = "${lib.getExe niriScripts.volume} down 1";
        tooltip-format = "{desc}";
      };

      network = {
        format-wifi = "󰖩  {signalStrength}%";
        format-ethernet = "󰈀  wired";
        format-linked = "󰈀  {ifname}";
        format-disconnected = "󰖪  offline";
        tooltip-format-wifi = "{essid}  ({signalStrength}%)\n{ipaddr}";
        tooltip-format-ethernet = "{ifname}\n{ipaddr}";
        on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
	on-click-right = "${pkgs.kitty}/bin/kitty -e ${pkgs.networkmanager}/bin/nmtui connect";
      };

      bluetooth = {
        format = "󰂯 {status}";
        format-connected = "󰂯 {device_alias}";
        format-connected-battery = "󰂯 {device_alias} {device_battery_percentage}%";
        on-click = "${pkgs.blueman}/bin/blueman-manager";
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

      # Sleep inhibitor. Same script as the Mod+Shift+I bind, so clicking and
      # keying stay in step.
      #
      # `signal` is what makes the icon change the instant it's toggled: the
      # script sends SIGRTMIN+8 and waybar re-runs the module. The interval
      # is only a backstop, in case the unit stops on its own (the inhibitor
      # dying, or swayidle being started by something else).
      "custom/idle-inhibitor" = {
        format = "{}";
        return-type = "json";
        exec = "${lib.getExe niriScripts.idleInhibit} status";
        interval = 30;
        signal = 8;
        on-click = "${lib.getExe niriScripts.idleInhibit} toggle";
      };

      # Lock, immediately to the left of the power button.
      #
      # Same `lock-now` the Mod+L bind and the session menu's "Lock" entry
      # run, so all three routes take the theme's colours and can't drift
      # apart. The power button next door opens a menu that also offers Lock;
      # this is the one-click version of the thing you do most often, which is
      # why it gets its own slot rather than living behind that menu.
      "custom/lock" = {
        format = "󰌾";
        tooltip = true;
        tooltip-format = "Lock the session";
        on-click = lib.getExe niriScripts.lockNow;
      };

      "custom/session" = {
        format = "⏻";
        tooltip = false;
        on-click = lib.getExe niriScripts.sessionMenu;
      };
    };
  };

  # NOTE: services.networkmanager-applet.enable = false is a no-op here and
  # was removed. That option gates home-manager's *own* nm-applet user
  # service, which was never enabled — the applet was started by niri's
  # spawn-at-startup instead. Setting it false changes nothing.
  #
  # The tray icon is dealt with in two places: the spawn is gone from
  # niri.nix, and the tray's ignore-list above catches it anyway, since the
  # networkmanagerapplet package ships an XDG autostart entry and niri's
  # session honours xdg-desktop-autostart.

  # Point waybar at the active theme's stylesheet. home-manager's generated
  # unit has no way to pass `-s`, so override ExecStart.
  systemd.user.services.waybar.Service.ExecStart = lib.mkForce (
    "${pkgs.waybar}/bin/waybar -s ${activeDir}/waybar.css"
  );
}
