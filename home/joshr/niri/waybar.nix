{ config, lib, pkgs, niriTheming, niriScripts, niriGamemode, ... }:

# Top bar.
#
#   left    workspaces + focused window title
#   centre  clock and date
#   right   tray, nowplaying, brightness, audio, network, battery and power
#           profile as one widget, caps lock and gamemode (each only while
#           it's on), session menu
#
# Theming: waybar is started with `-s <active theme>/waybar.css` and the
# switcher restarts it, so a theme change swaps the whole stylesheet. The
# `programs.waybar.style` option is deliberately not used — home-manager
# would write it to a store path that can't change at runtime.
let
  inherit (niriTheming) activeDir;

  # The whole file hangs off this. noctalia is the other shell and it draws
  # its own bar, so waybar is not merely redundant there but a second layer
  # surface reserving space at the top of every output.
  #
  # Gated here rather than force-disabled from ./noctalia.nix — the way the
  # other daemons it subsumes are — because of the `ExecStart` override at the
  # bottom of this file. A `systemd.user.services.<name>` attribute is written
  # out as a unit whether or not the module that owns the service is enabled,
  # so leaving that outside the guard would put a waybar.service on disk
  # holding nothing but an ExecStart line.
  useWaybar = config.local.niri.shell == "waybar";

  cavaEntry =
    if config.local.waybar.cavaInBar then
      "custom/cava"
    else
      "";

  # The display the backlight module reports, shared with the `brightness`
  # helper's OSD through the same option (scripts.nix). "" is how "unset"
  # reaches waybar — see the module below.
  brightnessDevice = config.local.niri.brightness.device;
  backlightDevice = if brightnessDevice == null then "" else brightnessDevice;
in
{
  programs.waybar = lib.mkIf useWaybar {
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

      # Gap waybar puts between every module in a group. Halved from 6 to
      # bring the right-hand cluster together — twelve slots at their widest,
      # and the gaps were doing more to separate them than the pills needed.
      #
      # It is one number for all three groups; there is no per-group spacing.
      # So the left group carries a 1px horizontal margin per module in the
      # stylesheet to make up the difference and stay exactly as it was, and
      # the right group's own margin is gone entirely (see theming.nix). The
      # centre is a single module and has no gaps to set.
      spacing = 4;

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
        "backlight"
        "pulseaudio"
        "bluetooth"
        "network"
        "privacy"
        "custom/microphone-privacy"
        "group/power"
        "custom/caps-lock"
        "custom/gamemode"
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
          # "^kitty$" = "  Terminal";
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

        title-len = 15;
        artist-len = 15;
        album-len = 15;
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

      # Display brightness, immediately left of the volume — the two controls
      # on the bar that are a level rather than a state, side by side.
      #
      # Scrolling goes through the same `brightness` script the
      # XF86MonBrightness keys use, for the reason that script exists at all:
      # `brightnessctl` with no `--device` moves the *first* backlight device
      # and leaves the rest alone, which is invisible on the laptop's single
      # internal panel and plainly wrong on the desk, where ddcci-backlight
      # registers one device per monitor (modules/nixos/ddcci.nix). Driving
      # the module's own stepping would have reintroduced exactly that bug on
      # the machine with two displays.
      #
      # Setting `on-scroll-up`/`on-scroll-down` replaces the built-in stepping
      # rather than adding to it: the backlight module hands scrolling off to
      # the generic handler as soon as either one is a string, the same shape
      # as `pulseaudio` below. So there is deliberately no `scroll-step` here
      # — it would look like it set the step, and the step is the 5 inside the
      # script.
      #
      # That 5 is also why nothing is passed to override it, where the volume
      # module's scroll passes an explicit 1. A notch moving less than a key
      # is the right instinct for a sink that answers instantly; a DDC/CI
      # write is a ~100ms round trip per display, and the script drops
      # overlapping runs rather than queueing them, so finer steps would only
      # mean more of a scroll landing on a held lock and being thrown away.
      #
      # Still waybar's built-in module and not a custom one, because the
      # reading has to be right no matter what moved the level — this scroll,
      # a media key, the pre-lock dim in lock.nix. All of those write the
      # device through sysfs, which is what the built-in module is watching;
      # it repaints on the uevent rather than waiting for its next poll. A
      # custom module would have nothing but the poll, and a `brightness`
      # helper that signalled waybar instead would still miss everything that
      # didn't go through it.
      #
      # `{percent}` is one device's level, and `device` is what decides which.
      # Left unset the module takes the device with the highest
      # `max_brightness` and breaks ties in udev enumeration order, while the
      # `brightness` helper takes whichever sorts first in
      # /sys/class/backlight — two different rules that happen to agree on a
      # laptop's single panel and need not agree on a desk with a `ddcci*`
      # device per monitor. Naming the device here and reading the same option
      # in scripts.nix makes the bar and the OSD quote the same screen. Unset
      # (`local.niri.brightness.device = null`) leaves both to their own idea
      # of first, which is what this did before.
      #
      # An empty string is how "unset" reaches waybar, and it means the same
      # thing to it: `best_device` looks for an exact name match and falls
      # through to the automatic choice when nothing matches.
      #
      # **`interval` is a DDC/CI round trip per display, not a sysfs read.**
      # The module's udev thread does an `epoll_wait` with this as its timeout
      # and re-reads every tracked device's `actual_brightness` whenever it
      # expires — and on a ddcci device that attribute is answered by asking
      # the monitor (see the header comment on `brightness` in scripts.nix).
      # At waybar's default of 2 seconds that is both monitors interrogated
      # over i2c every two seconds forever, including all through the ten
      # minutes the screen is blanked. 30 costs nothing that matters: the poll
      # is only the safety net for changes that emit no uevent, i.e. someone
      # pressing the buttons on the monitor itself. Everything that goes
      # through sysfs — these scrolls, the keys, the idle dim — emits one, and
      # a uevent wakes the epoll immediately.
      #
      # No click action. Volume has one because mute is a real toggle;
      # brightness has no equivalent, and a click that jumped to some fixed
      # level would be a worse thing to hit by accident than nothing at all.
      #
      # Both niri hosts have a backlight device — the laptop's panel, and one
      # per monitor on the desk once ddcci is loaded. On a host with none the
      # module draws no text but still holds its padding, unlike the custom
      # modules further right that waybar hides outright. That is the desk
      # before the reboot ddcci needs, and it corrects itself.
      backlight = {
        device = backlightDevice;
        interval = 30;
        format = "{icon}  {percent}%";
        format-icons = [ "󰃞" "󰃟" "󰃠" ];
        tooltip-format = "Brightness {percent}%";
        on-scroll-up = "${lib.getExe niriScripts.brightness} up";
        on-scroll-down = "${lib.getExe niriScripts.brightness} down";
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
        format-connected = "󰂯 connected";
        format-connected-battery = "󰂯 connected {device_battery_percentage}%";
	tooltip-format-connected = "{device_alias}";
        on-click = "${pkgs.blueman}/bin/blueman-manager";
      };

      # The charge and the power profile, drawn as one widget.
      #
      # They are two modules because waybar has no module that knows both, and
      # a custom one that did would have to reimplement what `battery` already
      # does for free: it repaints on udev events from the power supply rather
      # than on a timer, and it is what puts the `warning` and `critical`
      # classes on the pill at 30% and 15%. That is the same argument the
      # `backlight` module further up makes for not going custom — the reading
      # has to be right no matter what changed it.
      #
      # What waybar does offer is `group/`, which is a box holding several
      # modules with *zero* spacing between them, occupying one slot in the
      # bar. So the two halves meet flush where every other neighbouring pair
      # carries the bar's 4px `spacing`, and read as one control rather than
      # as two that happen to be adjacent. theming.nix does the rest.
      #
      # `orientation` is not optional even though this is a horizontal bar.
      # waybar's default is "orthogonal" — orthogonal to the *parent* — so
      # leaving it out would stack the charge above the profile inside a 34px
      # bar.
      #
      # The same group is right on every host with no condition around it,
      # because both halves hide themselves when they have nothing to say:
      # `battery` hides where there is no battery (the desk, and the stick
      # whenever it boots a desktop) and `power-profiles-daemon` hides when
      # nothing answers on the system bus. So the laptop draws both, the desk
      # draws the profile alone and it looks like any other pill, and neither
      # case needs to be spelled out here.
      "group/power" = {
        orientation = "horizontal";
        modules = [
          "battery"
          "power-profiles-daemon"
        ];
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

      # The active power profile, immediately right of the charge.
      #
      # Left click steps forward through the profiles the daemon offers, right
      # click steps back. That is the module's own handler and it replaces the
      # generic one outright, so unlike `pulseaudio` and `backlight` there is
      # no `on-click` here to keep in step with anything — and no way to add
      # one either.
      #
      # power-profiles-daemon is enabled for every graphical host in
      # modules/nixos/desktop.nix; without it this module draws nothing at
      # all, which is also what makes it safe to list unconditionally.
      #
      # Three different silhouettes rather than one needle in three positions:
      # a speedometer a few degrees further round is not something you can
      # read at 13px out of the corner of your eye, where a leaf, a pair of
      # scales and a dial are told apart at a glance. `default` is the
      # fallback for a profile the daemon offers under some other name. waybar
      # also puts a CSS class named after the active profile on the module, so
      # a fourth one gets its own glyph here and its own colour in theming.nix
      # — which is where the three below are coloured.
      #
      # `{profile}` is deliberately not in `format`. The right-hand cluster is
      # already twelve slots at its widest and the name says nothing the glyph
      # doesn't; it is in the tooltip, with the driver actually in force
      # underneath — which is the thing worth knowing, since a profile the
      # daemon accepts but has no driver for changes nothing.
      #
      # `{driver}` and not `{cpu_driver}`: the split into CPU and platform
      # drivers landed after waybar 0.15.0, and an unknown placeholder is a
      # format error rather than an empty string.
      "power-profiles-daemon" = {
        format = "{icon}";
        format-icons = {
          default = "󰊚";
          power-saver = "󰌪";
          balanced = "󰗑";
          performance = "󰓅";
        };
        tooltip-format = "Power profile: {profile}\nDriver: {driver}";
      };

      # Caps lock, between the battery and the idle inhibitor — and only while
      # the lock is actually on. The rest of the time the script prints an
      # empty line, waybar hides the module, and the bar is exactly what it
      # was before: no glyph, no gap, nothing held open.
      #
      # Same shape as custom/cava above, for the same reason. Continuous and
      # deliberately no `interval`: the script watches the keyboard's caps LED
      # and prints a line when it changes, so the glyph appears with the
      # keypress. `restart-interval` is the resilience — if the keyboard it is
      # watching goes away, the script exits and gets started again, which is
      # also how one plugged in later is picked up.
      #
      # This is not waybar's built-in `keyboard-state`, which reads the same
      # LED through libevdev and would need no script at all. It always draws
      # its label — "Caps" and a glyph, or with `{icon}` alone still an empty
      # label sitting in the layout — and a GTK stylesheet has no
      # `display: none` to take that out. Only a module waybar itself hides
      # costs nothing when it is off. See capsLockWatch in scripts.nix.
      #
      # Nor is it the caps lock OSD osd.nix deliberately doesn't run: that one
      # is a *system* service reading every input device to draw a pop-up. This
      # is the session's own bar, reading the keyboard the session is using.
      #
      # No tooltip. A glyph that is only ever on screen while caps lock is on
      # has already said the only thing it knows.
      "custom/caps-lock" = {
        format = "{}";
        exec = lib.getExe niriScripts.capsLock;
        restart-interval = 5;
        tooltip = false;
      };

      # GameMode, immediately right of caps lock and hidden the same way: the
      # script prints an empty line while GameMode is off, waybar hides the
      # module, and the slot costs nothing. Two indicators that are both
      # absent nearly all the time, side by side.
      #
      # It answers for the session's GameMode as well as the daemon's — a
      # `Mod+G` with no game running lights this exactly as a game does. See
      # ./gamemode.nix, which owns both the script and the mode.
      #
      # Polled rather than continuous, unlike its neighbour, because gamemode
      # has somewhere to ask — a D-Bus daemon with a status call — but nothing
      # to subscribe to from a shell. So it works the way the idle inhibitor
      # does: `signal` for the answer that matters and `interval` as the
      # backstop.
      #
      # SIGRTMIN+9 is sent by the gamemode start/end hooks in
      # modules/nixos/gaming.nix and by `niri-gamemode` itself, which is what
      # makes the pad appear as the mode is entered rather than up to 30
      # seconds afterwards. The numbers have to agree; nothing checks that they
      # do. 8 next door is the idle inhibitor's.
      "custom/gamemode" = {
        format = "{}";
        exec = lib.getExe niriGamemode.gamemodeStatus;
        interval = 30;
        signal = 9;
        tooltip = false;
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
  systemd.user.services.waybar = lib.mkIf useWaybar {
    Service.ExecStart = lib.mkForce "${pkgs.waybar}/bin/waybar -s ${activeDir}/waybar.css";
  };
}
