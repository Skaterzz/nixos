# PLACEHOLDER — this is not a real hardware scan.
#
# Regenerate it on the machine before the first build:
#
#   sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
#
# The UUIDs below belong to no disk that exists. Building against them
# produces a system that cannot find its root filesystem.
#
# Same situation as hosts/gamestation/ and hosts/server/ — see
# "Regenerating hardware-configuration.nix" in MANUAL.md.
#
# Written for bare metal rather than a guest, unlike hosts/server/'s, since
# the point of this host is a card plugged into it. `kvm-amd` is a guess at
# the CPU vendor and `kvm-intel` is the other one; the scan settles it.
#
# Nothing NVIDIA belongs in here. The driver, its kernel modules and the
# blacklisting of nouveau all come from modules/nixos/nvidia-server.nix, and
# a stray `nvidia` in `boot.initrd.kernelModules` is how a machine ends up
# trying to load a module the initrd doesn't contain.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
