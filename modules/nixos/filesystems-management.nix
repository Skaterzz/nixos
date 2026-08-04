{ pkgs, ... }:

# The command-line filesystem tools — mkfs, fsck, resize and label, for the
# four formats a disk plugged into this machine is actually going to be.
#
# The companion to ./disk-managements.nix and imported next to it. That module
# is the three GUIs; this one is what they run. Neither gparted nor kpmcore
# nor udisks2 implements a filesystem itself — every "format", "resize",
# "check" and "set label" in those windows is an exec of one of the binaries
# below, and a missing one is reported as the operation being unavailable
# rather than as a package that isn't installed.
#
# Which is why these are `environment.systemPackages` rather than a user
# profile. Two of the three callers are not the user:
#
#   * udisks2 runs as root from a systemd unit, and takes the system PATH —
#     /run/current-system/sw/bin, which is exactly what this list builds. That
#     covers GNOME Disks and the file manager's mount/format entries.
#   * kpmcore's helper is likewise a root process reached over D-Bus.
#
# gparted is the exception and does *not* read this list — pkexec sanitises
# its environment, so it only sees the PATH its own wrapper baked in. That is
# handled where gparted is installed, by `withAllTools` in
# ./disk-managements.nix; the two lists overlap for that reason rather than by
# accident.
#
# Mounting is a separate question and is not what this module is about. The
# kernel handles all four out of the box, so an exfat stick or a btrfs disk
# mounts without any of this — these packages are for making, checking and
# repairing them. `boot.supportedFilesystems` is the option for the mount
# side, and is only interesting for a root filesystem the initrd has to bring
# up.
{
  environment.systemPackages = with pkgs; [
    # btrfs: mkfs.btrfs, btrfs check/scrub/balance, and `btrfs restore`, which
    # pulls files off a volume too damaged to mount. Also what reads
    # subvolumes and snapshots — a btrfs disk looks like one filesystem to
    # everything else and the layout is only visible through this.
    btrfs-progs

    # exFAT: mkfs.exfat/fsck.exfat. The format cameras, phones and anything
    # over 4 GB on a shared stick actually use. exfatprogs is the current
    # implementation — the older exfat-utils/fuse pair it replaced is gone
    # from nixpkgs, and the kernel has had a native driver since 5.4, so this
    # is the userspace half of that and not a FUSE mount.
    exfatprogs

    # FAT12/16/32: mkfs.vfat, fsck.vfat, fatlabel. Not legacy — this is what
    # an EFI System Partition is, so it is the one on this list that a machine
    # which fails to boot most often needs.
    dosfstools

    # ext2/3/4: mkfs.ext4, e2fsck, resize2fs, tune2fs, dumpe2fs. Also the
    # bad-block scanner (`badblocks`) and `debugfs`, which reads an ext
    # filesystem that will not mount.
    e2fsprogs
  ];
}
