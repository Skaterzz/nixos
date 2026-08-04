{ config, lib, pkgs, modulesPath, ... }:

# This is a PLACEHOLDER, like every other hardware-configuration.nix in this
# repo — but it is a placeholder of a different shape, and the differences are
# the point rather than an accident of how it was generated.
#
# Regenerate the parts that describe *this stick* on the stick:
#   sudo nixos-generate-config --show-hardware-config > hosts/usb/hardware-configuration.nix
# and then put the module list and the labels below back, because
# nixos-generate-config writes what the machine it ran on needed, and this
# drive is going to be plugged into machines it has never met.
#
# Two rules follow from that, and they are the whole file:
#
#   * **Name filesystems by label, never by UUID or /dev/sdX.** UUIDs are
#     stable and would work; the letter is not — the stick is sdb on one
#     machine and sdd on the next, behind however many disks that machine
#     has. Labels are used here rather than UUIDs so that re-making the stick
#     doesn't mean editing this file, which is the operation this host is
#     most likely to need.
#
#         sudo mkfs.ext4  -L nixos-usb /dev/sdX2
#         sudo mkfs.vfat  -F 32 -n USB-BOOT /dev/sdX1
#         sudo e2label /dev/sdX2 nixos-usb      # relabel an existing one
#         sudo fatlabel /dev/sdX1 USB-BOOT
#
#     Both names are deliberately not "nixos" and "boot", which is what
#     hosts/laptop and hosts/gamestation use: plug this stick into one of
#     those machines while it is running and two filesystems answering to one
#     label is a coin toss over which gets mounted.
#
#   * **Carry every controller the root disk might be behind.** On a fixed
#     install the initrd only needs the driver for the disk that machine has.
#     Here the disk is the stick, and what sits between it and the CPU is a
#     USB controller belonging to a machine chosen at boot time.
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    # USB host controllers, newest to oldest. xhci is USB 3 and covers
    # anything current; the other three are for the machine old enough that
    # booting a rescue stick on it is the likely reason you are here.
    "xhci_pci"
    "ehci_pci"
    "ohci_pci"
    "uhci_hcd"

    # The stick itself. usb_storage is the mass-storage class driver; uas is
    # the faster USB Attached SCSI transport that USB 3 drives advertise, and
    # a drive that negotiates UAS and finds no driver falls back — slowly, or
    # not at all on some bridges. usbhid is the keyboard, which matters if the
    # initrd ever has to ask something.
    "usb_storage"
    "uas"
    "usbhid"

    # sd_mod is what turns any of the above into /dev/sd*. sr_mod is optical
    # media, cheap to carry and occasionally the thing being read.
    "sd_mod"
    "sr_mod"

    # The host machine's own disks. Not needed to boot this stick, and not
    # what makes them visible to gparted either — the booted system has the
    # whole module tree and udev loads these on sight. They are here for the
    # initrd's emergency shell, which is the one context that only has what
    # this list put in it, and which is a plausible place to end up on a
    # machine that is already not booting.
    "ahci"
    "nvme"
    "sdhci_pci"
  ];

  boot.initrd.kernelModules = [ ];

  # Deliberately empty. `kvm-intel` / `kvm-amd` is what a fixed install pins
  # here, and this machine does not know which CPU it has until it boots —
  # naming the wrong one logs a failed modprobe on every boot. The kernel
  # loads the right one on demand if anything ever asks for KVM.
  boot.kernelModules = [ ];

  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos-usb";
    fsType = "ext4";

    # `noatime` because this is flash with no wear levelling worth the name.
    # Default mount options write a timestamp back to the disk for every file
    # *read*, which on a stick is a write cycle spent on nothing.
    #
    # ext4 rather than btrfs, which the tools in
    # modules/nixos/filesystems-management.nix would also handle: this
    # filesystem gets yanked out of running machines, and ext4's journal is
    # the most boring recovery story of the options.
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/USB-BOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
      "noatime"
    ];
  };

  # No swap. A swap partition on a stick would be slow enough to look like a
  # hang, and `swapDevices` naming a partition that isn't there stalls the
  # boot waiting for it.
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Both vendors, because the CPU is whatever the machine has. Each is a
  # microcode blob prepended to the initrd and ignored by the CPU it doesn't
  # belong to, so carrying the pair costs a few megabytes on the boot
  # partition and nothing else.
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
