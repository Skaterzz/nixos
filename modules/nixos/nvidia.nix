{ config, lib, pkgs, ... }:

# The NVIDIA driver, and what it takes to come back from suspend.
#
# Only the two `gamestation` hosts import this — the laptop has no discrete
# NVIDIA card (hosts/laptop/configuration.nix says so at length), so nothing
# here has to consider Optimus, PRIME or a battery.
#
# This is the *desktop* driver: a card driving monitors, 32-bit libraries for
# Proton, and the suspend dance below. A card in a headless box wants
# modules/nixos/nvidia-server.nix instead — persistence rather than suspend,
# the container toolkit, and the NVENC/NvFBC patch. Import one or the other;
# both write `hardware.nvidia.package`.
#
# Waking up
# ---------
# By default the driver throws video memory away when the machine suspends.
# Nothing warns you: the suspend works, the machine wakes, the fans spin, and
# the session never comes back — the compositor's framebuffers, textures and
# GL/Vulkan contexts all lived in memory the driver no longer has, so niri
# cannot take the GPU back and you get a black screen with a live machine
# behind it (SSH in and `systemctl restart display-manager` is the usual way
# to prove that to yourself).
#
# `powerManagement.enable` is the fix, and it is three things at once:
#
#   * `NVreg_PreserveVideoMemoryAllocations=1` on the nvidia module, which is
#     what tells the driver to save allocations instead of dropping them.
#
#   * nvidia-suspend.service and nvidia-hibernate.service, ordered *before*
#     systemd-suspend.service / systemd-hibernate.service, which write
#     "suspend"/"hibernate" to /proc/driver/nvidia/suspend so the save
#     actually happens while there is still a machine to save from.
#
#   * nvidia-resume.service, ordered *after* both, which writes "resume" and
#     puts the memory back.
#
# All three are `${nvidia_x11}/bin/nvidia-sleep.sh <state>`; nixpkgs
# generates the units. Check them on the machine after a rebuild:
#
#     systemctl list-unit-files 'nvidia-*'
#     cat /proc/driver/nvidia/params | grep PreserveVideoMemoryAllocations
#
# Where the video memory goes
# ---------------------------
# To a file under /tmp — `NVreg_TemporaryFilePath` — sized by how much of the
# card is in use, so gigabytes on a card this size. On this machine /tmp is a
# directory on the root btrfs subvolume (hosts/gamestation/hardware-configuration.nix,
# and nothing here sets `boot.tmp.useTmpfs`), so that is real disk and the
# default is right.
#
# It stops being right the moment /tmp becomes a tmpfs: the "save" would then
# be a copy from RAM to RAM, which doubles the memory a suspend needs and
# makes hibernation impossible. If `boot.tmp.useTmpfs` is ever turned on here,
# point the driver somewhere on disk in the same breath:
#
#     hardware.nvidia.moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # needed for Steam/Proton
  };

  hardware.nvidia = {
    # Required for Plasma Wayland sessions.
    modesetting.enable = true;

    # Save and restore video memory across suspend and hibernate. See the
    # header — without this the machine resumes to a black screen.
    powerManagement.enable = true;

    # Keep the three nvidia-{suspend,hibernate,resume} services.
    #
    # This looks redundant and isn't. The driver gained a second mechanism —
    # it registers with the kernel's own PM notifier chain and does the
    # save/restore itself, no systemd units involved — and nixpkgs turns that
    # on *by default* for the open modules on a driver this new. When it is
    # on, the three services above are not generated at all, so a rebuild
    # would leave `systemctl list-unit-files 'nvidia-*'` as empty as it is
    # today and it would look like nothing had changed.
    #
    # False pins the systemd path, which is the older and far more widely
    # travelled of the two. `NVreg_PreserveVideoMemoryAllocations=1` is set
    # either way; the choice is only about who drives the save and restore.
    #
    # To try the newer mechanism, delete this line and rebuild: the nvidia-*
    # units disappear and `NVreg_UseKernelSuspendNotifiers=1` shows up in
    # /proc/driver/nvidia/params instead. It is worth a go if resume is still
    # unreliable with the services in place — it removes an ordering problem
    # rather than working around one.
    powerManagement.kernelSuspendNotifier = false;

    # Runtime D3 for a PRIME offload GPU. Nothing on this machine is offload
    # — the NVIDIA card drives the displays directly — and nixpkgs asserts
    # that this requires `prime.offload.enable`, so it stays off.
    powerManagement.finegrained = false;

    # Turing (RTX 20xx) and newer can use the open kernel module instead.
    # Flip this to `true` if your card supports it.
    open = false;

    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
