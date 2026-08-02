{ config, lib, pkgs, ... }:

{
  # OpenRGB: the daemon, and re-applying the profile after a suspend.
  #
  # It lived here as four lines and moved out when the resume half was added.
  # Still imported from this file rather than per host, so the hosts that had
  # RGB before still have it and nothing had to be edited to keep it. Its
  # `local.openrgb.*` options are in modules/nixos/options.nix.
  imports = [ ./openrgb.nix ];

  # MangoHud isn't here at all: it's configured per-user in
  # home/joshr/home.nix, through home-manager's programs.mangohud rather than
  # a NixOS-level option.

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
  };

  programs.gamescope = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    prismlauncher
    protonup-qt
    lutris
  ];

  programs.gamemode = {
    enable = true;

    settings = {
      # Both hooks poke waybar as well as notifying. Its custom/gamemode
      # module is otherwise on a 30-second poll, and a mode you turn on for a
      # game should show up in the bar as the game starts rather than up to
      # half a minute later. SIGRTMIN+9 is the `signal` that module is given
      # in home/joshr/niri/waybar.nix — the two numbers have to agree, and
      # nothing checks that they do.
      #
      # `|| true` because pkill exits 1 when nothing matches, which is the
      # ordinary case in a Plasma session with no waybar running, and
      # gamemoded logs a non-zero script as a failure.
      #
      # The `;` is real shell: gamemode runs these through `/bin/sh -c`
      # (game_mode_execute_scripts in daemon/gamemode-context.c), not execvp
      # on a split string, which is also why the quoted notification title
      # works.
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send -i input-gamepad 'GameMode started'; ${pkgs.procps}/bin/pkill -RTMIN+9 waybar || true";
        end = "${pkgs.libnotify}/bin/notify-send -i input-gamepad 'GameMode ended'; ${pkgs.procps}/bin/pkill -RTMIN+9 waybar || true";
      };
    };
  };
}
