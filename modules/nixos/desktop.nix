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

        # make airpods work
        ControllerMode = "bredr";
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = true; };
      }; };
    services.blueman.enable = true;

    hardware.enableAllFirmware = true;
}
