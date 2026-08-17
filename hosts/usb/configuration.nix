{ config, lib, pkgs, ... }:

# The stick. A full NixOS install on a USB drive, meant to be carried and
# booted on whatever machine is in front of you — to fix that machine's disks,
# to read a drive nothing else will read, or just to have this desktop
# somewhere that isn't this desktop.
#
#   sudo nixos-rebuild switch --flake .#usb
#
# It is not an installer ISO. There is no `nixos-install` here and nothing is
# read-only: it is a persistent niri system, so it keeps state, updates like
# any other host, and is rebuilt from this repo rather than regenerated.
#
# Three things follow from living on a stick:
#
#   1. **It boots on hardware it has never seen.** No NVIDIA module, no kernel
#      command line tuned to one board, no display layout — the initrd carries
#      the USB controllers and every disk driver, and niri detects the outputs
#      it finds. See ./hardware-configuration.nix.
#   2. **It must not write to the host machine.** The bootloader is installed
#      at the removable-media path and NVRAM is left alone; see the boot
#      section below.
#   3. **Whoever holds it is logged in.** Auto-login, one account, and the
#      lock screen and sudo password are all that is between the stick and
#      the person who found it. See the auto-login section.
{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix

    # niri: the session, SDDM, portals, audio and the polkit agent — which the
    # partition editors below need, since asking polkit for root gets you
    # nothing if no agent is running to ask you.
    ../../modules/nixos/niri.nix

    # Bluetooth, firmware for everything, and the file-association baseline —
    # ../../modules/nixos/default-apps.nix arrives with this one.
    ../../modules/nixos/desktop.nix

    # Fluent Emoji as the system emoji font. The picker is Mod+. — see
    # home/joshr/niri/emoji.nix.
    ../../modules/nixos/emoji.nix

    # The reason this host exists. gparted, KDE Partition Manager and GNOME
    # Disks; then the mkfs/fsck binaries all three of them shell out to.
    ../../modules/nixos/disk-managements.nix
    ../../modules/nixos/filesystems-management.nix

    # joshr, and no one else. Not ../../modules/nixos/users.nix, which is the
    # shared machines and carries two more accounts.
    ../../modules/nixos/usb-users.nix

    # NOT imported: nvidia.nix, gaming.nix, ai.nix, virtualization.nix,
    # ddcci.nix. Each is either tied to one machine's hardware or is tens of
    # gigabytes that a stick does not have to spare.
    #
    # NOT imported: development.nix. Docker on removable media is a lot of
    # writes to flash for something this host isn't for. Adding it is one
    # line, and usb-users.nix already handles the group membership.
    #
    # NOT imported: plasma-xdg-data-dirs.nix — no plasma-workspace in a niri
    # session, so nixpkgs#126590 cannot bite here.
  ];

  networking.hostName = "porygon";

  # A stick has no idea what hardware it will run on. These settings save
  # power and handle a lid when it is booted on a laptop, while remaining
  # harmless on a desktop where no battery or lid exists.
  boot.kernelParams = [ "mem_sleep_default=deep" ];
  powerManagement.enable = true;
  services.upower.enable = true;
  services.thermald.enable = lib.mkDefault true;
  services.fstrim.enable = true;
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "ignore";
  };

  # --- boot: removable media ---------------------------------------------
  #
  # A stick has to boot on a machine that has never heard of it, and — more
  # importantly — must not change that machine on its way past.
  #
  # GRUB rather than the limine default. `efiInstallAsRemovable` runs
  # `grub-install --removable`, which writes the loader to the one path UEFI
  # firmware will boot without being told to: <esp>/EFI/BOOT/BOOTX64.EFI, the
  # removable-media fallback. limine has no equivalent here, and the themed
  # boot menu it is the default for is worth very little on a device whose
  # whole job happens after boot.
  local.boot.loader = "grub";
  boot.loader.grub.efiInstallAsRemovable = true;

  # The other half of the same decision, and the one that keeps the host
  # machine untouched.
  #
  # `canTouchEfiVariables` lets the installer write an NVRAM boot entry. On a
  # fixed disk that is how the firmware learns the machine is bootable; from a
  # stick it is vandalism — a permanent entry, on someone else's motherboard,
  # pointing at a drive that will not be there next time. Some firmware
  # refuses the write, some has no free space for it, and a rebuild would fail
  # on either.
  #
  # mkForce because modules/nixos/boot.nix sets it true for all three loaders,
  # which is right for every other host in this repo. GRUB also asserts these
  # two cannot both be on, so getting it wrong stops the build rather than
  # producing a stick that quietly edits machines.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # os-prober off. It scans the disks present *at rebuild time* and bakes what
  # it finds into grub.cfg — so the menu would advertise the Windows install
  # of whichever machine the stick was last updated on, and offer it on every
  # machine after that.
  local.boot.detectOtherSystems = false;

  # No boot splash either, and left off rather than written down as `false`:
  # `local.boot.plymouth.enable` defaults off and the four fixed graphical
  # hosts are the ones that turn it on. This is the machine that boots on
  # hardware it has never seen, so the boot most likely to need explaining is
  # exactly the one a splash would paint over. See modules/nixos/plymouth.nix
  # for the one line that changes that.

  # --- auto-login ---------------------------------------------------------
  #
  # Boot to the desktop. There is one account (modules/nixos/usb-users.nix)
  # and one session, so a greeter here is a password prompt in front of a list
  # with a single entry — and the machine this stick is being used on is
  # frequently one that has just failed to boot, at a moment when fewer steps
  # is the entire point.
  #
  # **What this costs.** Physical possession becomes a login. The stick's
  # password still guards `sudo` and the lock screen, but nothing is asked for
  # between power-on and joshr's home directory, and nothing on it is
  # encrypted — the same is true of any unencrypted install, it is just easier
  # to walk off with this one. If that trade stops being the right one, delete
  # these two options: the greeter comes back and everything else here is
  # unchanged.
  #
  # Logging out still returns to the greeter rather than looping straight back
  # in — SDDM's `autoLogin.relogin` defaults to false, which means "on boot,
  # not on every session end", and that is the behaviour wanted here.
  services.displayManager.autoLogin = {
    enable = true;
    user = "joshr";
  };

  # Which session auto-login starts. With niri the only session package
  # installed, SDDM would land on it anyway — this states it so that adding a
  # second session later doesn't silently change what the stick boots into.
  services.displayManager.defaultSession = "niri";

  # The greeter is left at the stock one (`local.sddm.theme` defaults to
  # "stock"). Auto-login means it is only seen after an explicit logout, which
  # is not worth per-palette theme packages and a sync service on a device
  # where disk space is the scarce thing.

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "26.05";
}
