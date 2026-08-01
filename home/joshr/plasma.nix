{ inputs, lib, config, ... }:

# KDE Plasma 6 configuration ported from joshrandall8478/dotfiles
# (kdeglobals, plasmarc, kwinrc, kglobalshortcutsrc, plasma-org.kde.plasma.desktop-appletsrc).
#
# Machine/session-specific noise was intentionally dropped: window-tiling
# geometry caches, per-instance applet UUIDs, activity UUIDs, and dialog-size
# memory. Everything that reflects an actual choice you made was kept.
#
# If you change something in System Settings later and want it captured here,
# run `nix run github:nix-community/plasma-manager` (the `rc2nix` tool) and
# diff its output against this file.
{
  programs.plasma = {
    enable = true;

    workspace = {
      lookAndFeel = "org.kde.breezedark.desktop";
      colorScheme = "DarkObsidianII";
      iconTheme = "Papirus";
      theme = "Fluent-round-Pursuit";
      cursor = {
        theme = "Bibata-Modern-Ice";
        size = 24;
      };
      splashScreen.theme = "cachyos-breeze-splash";
      windowDecorations = {
        library = "org.kde.breeze";
        theme = "Breeze";
      };
      wallpaper = "${inputs.dotfiles}/dot_local/share/wallpapers/Anime/shinobu.png";
    };

    fonts.general = {
      family = "Poppins";
      pointSize = 10;
    };

    kscreenlocker = {
      lockOnResume = true;
    };

    # No automatic suspend while plugged in.
    #
    # modules/nixos/power.nix already holds a logind idle inhibitor on mains
    # power, and powerdevil honours it — but powerdevil is the thing with the
    # timer, so saying it here as well means the behaviour doesn't depend on
    # one daemon asking another the right question. The battery and
    # lowBattery profiles are left alone: on battery, sleeping is the point.
    #
    # Screen locking and blanking are untouched; those are separate settings.
    powerdevil.AC.autoSuspend.action = "nothing";

    # Global shortcuts that were actually customized (everything else in
    # kglobalshortcutsrc was the stock KDE default and isn't worth restating).
    shortcuts = {
      "services/kitty.desktop"."_launch" = "Meta+Return";
      "services/org.kde.dolphin.desktop"."_launch" = "Meta+E";

      # The emoji picker. This one *is* the KDE default and breaks the rule
      # above, deliberately: the niri session binds Mod+. to a picker of its
      # own (home/joshr/niri/emoji.nix), and stating the Plasma side here is
      # what stops the same key from quietly meaning different things — or
      # nothing — depending on which session booted. It costs one line and
      # survives KDE changing its mind about the default.
      #
      # Plasma ships the picker itself (plasma-emojier, part of plasma-
      # desktop), so there's nothing to install. It draws whatever fontconfig
      # calls the emoji font, which modules/nixos/emoji.nix makes Fluent
      # Emoji — so both sessions show the same artwork.
      "services/org.kde.plasma.emojier.desktop"."_launch" = "Meta+.";
    };

    # Raw config-file settings that don't (yet) have a dedicated high-level
    # plasma-manager option.
    configFile = {
      kwinrc = {
        Desktops = {
          Number = 3;
          Rows = 1;
        };
        "Effect-blur" = {
          BlurStrength = 4;
          NoiseStrength = 3;
        };
        "Effect-diminactive".DimFullScreen = false;
        "Effect-magiclamp".AnimationDuration = 400;
        "Effect-overview".BorderActivate = 9;
        "Effect-translucency".Inactive = 90;
        Plugins = {
          blurEnabled = true;
          desktopchangeosdEnabled = true;
          gamecontrollerEnabled = false;
        };
        "Script-desktopchangeosd" = {
          PopupHideDelay = 970;
          TextOnly = true;
        };
        Xwayland = {
          Scale = 1;
          XwaylandEisNoPrompt = true;
        };
      };

      plasmarc.Wallpapers.usersWallpapers = lib.concatStringsSep "," (
        map (name: "/home/joshr/.local/share/wallpapers/${name}") [
          "Retro Computing.jpg"
          "Gentoo Chan Full.png"
          "Gentoo Chan Full Light.png"
          "Japanese Castle.png"
          "Japanese Street.jpg"
          "Chained Hands.jpg"
          "drowning.png"
          "Windows 7 Dolls.jpg"
          "Anime/demon.png"
        ]
      );

      kscreenlockerrc."Greeter/Wallpaper/org.kde.image/General" = {
        Image = "file:///home/joshr/.local/share/wallpapers/Anime/shinobu.png";
        PreviewImage = "file:///home/joshr/.local/share/wallpapers/Anime/shinobu.png";
        SlidePaths = "/home/joshr/.local/share/wallpapers/,/usr/share/wallpapers/";
      };

      klaunchrc = {
        BusyCursorSettings.Bouncing = false;
        FeedbackStyle.BusyCursor = false;
      };

      krunnerrc.General.FreeFloating = true;

      # Remaining kdeglobals settings from the dotfiles. The colour palette
      # itself comes from workspace.colorScheme (DarkObsidianII) and the fonts
      # from fonts.general; these are the leftovers with no dedicated
      # plasma-manager option.
      kdeglobals = {
        General = {
          # Default browser/terminal, used by "open link" and
          # "open terminal here" actions across KDE.
          #
          # `vivaldi-stable.desktop`, not `vivaldi.desktop`: nixpkgs copies
          # the upstream .deb's desktop entry across without renaming it, so
          # that is the entry ID KDE looks up. See home/joshr/browser.nix.
          BrowserApplication = "vivaldi-stable.desktop";
          TerminalApplication = "kitty";
          TerminalService = "kitty.desktop";

          AccentColor = "184,69,61";
          accentColorFromWallpaper = true;
          LastUsedCustomAccentColor = "233,61,88";

          # Font rendering.
          XftAntialias = true;
          XftHintStyle = "hintslight";
          XftSubPixel = "none";
        };
        KDE = {
          # ~0.354 — noticeably snappier than the 1.0 default. This one is
          # very visible; without it every animation runs ~3x longer.
          AnimationDurationFactor = 0.35355339059327373;
          ShowDeleteCommand = false;
          contrast = 0;
          frameContrast = 0.2;
        };
        PreviewSettings = {
          EnableRemoteFolderThumbnail = false;
          MaximumRemoteSize = 1048576000;
        };
      };
    };

    panels = [
      # Main dock: screen 0, bottom edge (was Containments[4] / PlasmaViews
      # "Panel 4"). thickness=50, panelLengthMode=1 (FitContent),
      # panelOpacity=2 (Translucent), panelVisibility=2 (DodgeWindows),
      # alignment=132 (Qt AlignHCenter|AlignVCenter).
      {
        screen = 0;
        location = "bottom";
        floating = true;
        height = 50;
        lengthMode = "fit";
        alignment = "center";
        opacity = "translucent";
        hiding = "dodgewindows";
        widgets = [
          {
            kickoff = {
              icon = "/home/joshr/.local/share/icons/j-contrast.svg";
              sidebarPosition = "right"; # paneSwap=true
              applicationsDisplayMode = "grid"; # applicationsDisplay=0
              showButtonsFor = "powerAndSession"; # primaryActions=3
              popupHeight = 526;
              popupWidth = 1147;
            };
          }
          {
            iconTasks = {
              # Full launcher list from the dotfiles. Joplin, Shelly and
              # Thunderbird are pinned there but aren't installed by this
              # config, so those three will show as dead entries until you
              # add the packages (or drop the lines).
              launchers = [
                # See BrowserApplication above for the -stable suffix.
                "applications:vivaldi-stable.desktop"
                "applications:kitty.desktop"
                "applications:org.kde.dolphin.desktop"
                "applications:spotify.desktop"
                "applications:discord.desktop"
                "applications:signal.desktop"
                "applications:steam.desktop"
                "applications:code.desktop"
                "applications:systemsettings.desktop"
              ];
              appearance.indicateAudioStreams = false;
              # No dedicated option for this one yet.
              settings.General.interactiveMute = false;
            };
          }
          "org.kde.plasma.showdesktop"
        ];
      }

      # Status bar: screen 0, top edge (was Containments[101] / PlasmaViews
      # "Panel 101"). thickness=32, panelLengthMode=0 (FillAvailable),
      # panelVisibility=0 (NormalPanel). The stored min/maxLength (2416/2490)
      # only apply in Custom length mode, so they're intentionally omitted.
      {
        screen = 0;
        location = "top";
        floating = true;
        height = 32;
        lengthMode = "fill";
        hiding = "normalpanel";
        widgets = [
          {
            pager.general = {
              displayedText = "desktopNumber";
              showOnlyCurrentScreen = true;
              showApplicationIconsOnWindowOutlines = true;
            };
          }
          "org.kde.plasma.windowlist"
          "org.kde.plasma.panelspacer"
          {
            digitalClock = {
              date = {
                enable = true;
                format.custom = "ddd, MMM d";
                position = "besideTime";
              };
              # 12-hour rather than whatever the locale decides, so this
              # can't drift from the niri bar and the login screen.
              time.format = "12h";
            };
          }
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.mediacontroller"
          {
            systemTray.items = {
              shown = [
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.brightness"
                "org.kde.plasma.battery"
                "org.kde.plasma.notifications"
              ];
              extra = [
                "org.kde.kdeconnect"
                "org.kde.plasma.keyboardindicator"
                "org.kde.plasma.weather"
                "org.kde.kscreen"
                "org.kde.plasma.keyboardlayout"
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.volume"
                "org.kde.plasma.cameraindicator"
                "org.kde.plasma.clipboard"
                "org.kde.plasma.devicenotifier"
                "org.kde.plasma.manage-inputmethod"
              ];
              configs."org.kde.plasma.weather".config = {
                Appearance = {
                  showTemperatureInBadge = true;
                  showTemperatureInCompactMode = true;
                };
                WeatherStation = {
                  placeDisplayName = "Detroit, United States, US";
                  placeInfo = "Detroit, United States, US|4990729";
                  provider = "bbcukmet";
                };
              };
            };
          }
          {
            # No plasma-manager module for this widget, so raw config.
            name = "org.kde.plasma.lock_logout";
            config.General.actionsOrder = [
              "lockScreen"
              "switchUser"
              "suspendToRam"
              "requestReboot"
              "requestShutDown"
              "requestLogout"
              "requestLogoutScreen"
              "suspendToDisk"
            ];
          }
        ];
      }

    ]
    ++ lib.optionals config.local.plasma.secondaryMonitorPanel [
      # Second monitor: top edge (was Containments[63] / PlasmaViews
      # "Panel 63"). thickness=32, panelOpacity=0 (Adaptive),
      # panelVisibility=0 (NormalPanel).
      {
        screen = 1;
        location = "top";
        floating = true;
        height = 32;
        lengthMode = "fill";
        opacity = "adaptive";
        hiding = "normalpanel";
        widgets = [
          {
            pager.general = {
              displayedText = "desktopNumber";
              showOnlyCurrentScreen = true;
              showApplicationIconsOnWindowOutlines = true;
            };
          }
          "org.kde.plasma.windowlist"
          "org.kde.plasma.panelspacer"
          {
            digitalClock = {
              date = {
                enable = true;
                format.custom = "ddd, MMM d";
                position = "besideTime";
              };
              time.format = "12h";
            };
          }
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.mediacontroller"
          "org.kde.plasma.volume"
        ];
      }
    ];
  };
}
