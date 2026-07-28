{ inputs, lib, ... }:

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
      wallpaper = "${inputs.dotfiles}/dot_local/share/wallpapers/Anime/Yor.jpg";
    };

    fonts.general = {
      family = "Poppins";
      pointSize = 10;
    };

    kscreenlocker = {
      lockOnResume = true;
    };

    # Global shortcuts that were actually customized (everything else in
    # kglobalshortcutsrc was the stock KDE default and isn't worth restating).
    shortcuts = {
      "services/kitty.desktop"."_launch" = "Meta+Return";
      "services/org.kde.dolphin.desktop"."_launch" = "Meta+E";
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
        Image = "file:///home/joshr/.local/share/wallpapers/Anime/Yor.jpg";
        PreviewImage = "file:///home/joshr/.local/share/wallpapers/Anime/Yor.jpg";
        SlidePaths = "/home/joshr/.local/share/wallpapers/,/usr/share/wallpapers/";
      };

      klaunchrc = {
        BusyCursorSettings.Bouncing = false;
        FeedbackStyle.BusyCursor = false;
      };

      krunnerrc.General.FreeFloating = true;
    };

    panels = [
      # Main dock: screen 0, bottom edge (was Containments[4]).
      {
        screen = 0;
        location = "bottom";
        floating = true;
        widgets = [
          {
            kickoff = {
              icon = "/home/joshr/.local/share/icons/j-contrast.svg";
              sidebarPosition = "right";
              applicationsDisplayMode = "grid";
              showButtonsFor = "powerAndSession";
            };
          }
          {
            iconTasks.launchers = [
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
          }
          "org.kde.plasma.showdesktop"
        ];
      }

      # Status bar: screen 0, top edge (was Containments[101]).
      {
        screen = 0;
        location = "top";
        floating = true;
        widgets = [
          { pager.general.displayedText = "desktopNumber"; }
          "org.kde.plasma.windowlist"
          "org.kde.plasma.panelspacer"
          {
            digitalClock.date = {
              enable = true;
              format.custom = "ddd, MMM dd";
              position = "besideTime";
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
          "org.kde.plasma.lock_logout"
        ];
      }

      # Second monitor: top edge (was Containments[63]).
      {
        screen = 1;
        location = "top";
        floating = true;
        widgets = [
          { pager.general.displayedText = "desktopNumber"; }
          "org.kde.plasma.windowlist"
          "org.kde.plasma.panelspacer"
          {
            digitalClock.date = {
              enable = true;
              format.custom = "ddd, MMM d";
              position = "besideTime";
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
