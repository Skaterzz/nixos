{ config, lib, pkgs, ... }:

{
    # Baseline file associations in /etc/xdg, deliberately left overridable
    # from a settings panel. See the module for why they aren't home-manager's
    # `xdg.mimeApps` any more. Here rather than per-host because all four
    # desktop hosts import this file and the server doesn't.
    imports = [ ./default-apps.nix ];

    hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported
        # Bluetooth adapters. Defaults to 'false'.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption. Defaults to
        # 'false'.
        FastConnectable = true; 
        Enable = "Source,Sink,Media,Socket";

        # make airpods work and support passkeys
        ControllerMode = "dual";
	# Disable device cache for passkey support
	Cache = "no";
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = true; };
      }; };
    services.blueman.enable = true;

    hardware.enableAllFirmware = true;

    # Power profiles — power-saver, balanced, performance — and the daemon
    # that owns them.
    #
    # This is shared desktop policy rather than portable-hardware policy. Every
    # graphical configuration draws the profile somewhere: under Plasma
    # it is the switcher inside the battery applet (which is also where the
    # `Meta+B` shortcut from the dotfiles lands), and under niri it is the
    # `power-profiles-daemon` module in home/joshr/niri/waybar.nix. That
    # module hides itself outright when nothing answers on the system bus, so
    # on a host without this line the widget simply doesn't exist.
    #
    # The desk gets it for its own sake and not just to have something to
    # draw: `amd_pstate` exposes the same three profiles to a desktop CPU, and
    # "performance" before a game is the opposite of "quiet". Where the CPU
    # driver cannot offer them, the
    # daemon still answers with a placeholder and the widget still reads
    # `balanced` — it just doesn't change anything.
    #
    # `powerprofilesctl` arrives with it (the NixOS module puts the package in
    # environment.systemPackages), which is how to read or set the profile
    # from a shell or a script.
    #
    # TLP and auto-cpufreq want the same knobs and nixpkgs asserts if either
    # is on alongside this. Nothing in this config enables them, and picking
    # one up later means turning this off in the same edit.
    services.power-profiles-daemon.enable = true;

    # Firewall
    networking.firewall.allowedTCPPorts= [
      53317 # Localsend
    ];

    networking.firewall.allowedUDPPorts = [
      53317 # Localsend
    ];

    # HEIC/HEIF support (fuck apple)
    environment.systemPackages = [
      pkgs.libheif.bin  # provides heif-thumbnailer
      pkgs.libheif.out  # provides heif.thumbnailer
    ];
}
