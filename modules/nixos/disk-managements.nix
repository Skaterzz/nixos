{ pkgs, ... }:

# Partitioning and disk inspection, as graphical tools.
#
# Written for `usb` — the portable stick, whose whole reason to exist is being
# plugged into a machine whose disks need looking at — but there is nothing
# host-specific in here, so any host that wants the same three can import it.
#
# Three tools that overlap on purpose. They are not redundant so much as
# differently reliable, and on a rescue stick "the other one opens it" is the
# feature:
#
#   gparted             the partition table. GTK, and the one that has been
#                       doing this longest. Shells out to the filesystem
#                       tools for every resize/format, which is what makes
#                       `withAllTools` below matter.
#   KDE Partition       the same job, Qt, and it draws the KDE palette the
#   Manager             rest of this session wears. Talks to kpmcore rather
#                       than to mkfs directly, and reads SMART.
#   GNOME Disks         *not* a partition editor first. It is the udisks2
#                       front end: SMART and self-tests, benchmarking,
#                       mount/unmount, and writing a disk image to a stick —
#                       the things the other two don't do.
#
# All three want root and none of them are setuid. They ask polkit for it,
# which means each needs its policy file installed and an authentication agent
# running in the session. The agent is the desktop module's job
# (modules/nixos/niri.nix starts polkit-kde-agent); the policies arrive with
# the packages, with the caveat under partition-manager below.
{
  # KDE Partition Manager, through its own NixOS module rather than as a
  # package in the list below.
  #
  # The module is not a convenience wrapper — it is load-bearing. The
  # privileged half of this program is kpmcore's `externalcommand` helper, and
  # that helper is reached over the system D-Bus, so kpmcore has to be in
  # `services.dbus.packages` for its service file and its polkit action to be
  # installed. Adding `kdePackages.partitionmanager` to systemPackages alone
  # gets you a window that opens, finds the disks, and then fails on every
  # operation with a permission error and no clue why.
  programs.partition-manager.enable = true;

  # GNOME Disks is a client, not a daemon: everything it does — reading SMART,
  # mounting, formatting, writing an image — is a D-Bus call into udisks2. It
  # opens onto an empty window without this.
  #
  # modules/nixos/niri.nix already enables it for removable media in the file
  # manager. Stated again here so this module stands on its own; two modules
  # setting one option to the same value is not a conflict.
  services.udisks2.enable = true;

  environment.systemPackages = with pkgs; [
    # `withAllTools` is what makes gparted able to *act* on the filesystems
    # rather than only recognise them. Its wrapper builds gparted's PATH at
    # build time, and the default carries dosfstools, e2fsprogs and
    # util-linux and nothing else — so a stock gparted greys out "format as
    # btrfs" and "format as exfat" even on a machine that has btrfs-progs and
    # exfatprogs installed system-wide, which this one does
    # (./filesystems-management.nix).
    #
    # The system PATH cannot rescue it either, and that is the part worth
    # knowing: gparted is launched through pkexec, which sanitises the
    # environment it hands the privileged process. What survives is what the
    # wrapper put there.
    #
    # The cost is that this is an override, so it is not the build
    # cache.nixos.org has: gparted compiles here, once, and again after a
    # nixpkgs bump that moves it. It is a small C++ program — the extra tools
    # it names (bcachefs, hfs, jfs, nilfs, xfs, udf, ntfs-3g, cryptsetup,
    # lvm2) are cached and only join its PATH. Drop the `.override` for the
    # cached build and a partition editor that can do FAT and ext only.
    (gparted.override { withAllTools = true; })

    gnome-disk-utility
  ];
}
