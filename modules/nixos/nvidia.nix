{ config, lib, pkgs, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # needed for Steam/Proton
  };

  hardware.nvidia = {
    # Required for Plasma Wayland sessions.
    modesetting.enable = true;

    powerManagement.enable = false;
    powerManagement.finegrained = false;

    # Turing (RTX 20xx) and newer can use the open kernel module instead.
    # Flip this to `true` if your card supports it.
    open = true;

    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
