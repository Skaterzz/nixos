# Generated from this machine's hardware configuration.
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/4c9a1d98-ad8f-4594-add1-9efa10ae3dab";
    fsType = "btrfs";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/4c9a1d98-ad8f-4594-add1-9efa10ae3dab";
    fsType = "btrfs";
    options = [ "subvol=home" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/4c9a1d98-ad8f-4594-add1-9efa10ae3dab";
    fsType = "btrfs";
    options = [ "subvol=nix" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/6318-AA20";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/40962433-450f-40a4-907f-fc52015840c6"; }
  ];
  boot.resumeDevice = "/dev/disk/by-uuid/40962433-450f-40a4-907f-fc52015840c6";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
