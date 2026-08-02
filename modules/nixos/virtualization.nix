{ pkgs, ... }:

# QEMU/KVM guests and the virt-manager GUI that drives them.
#
# Split out of modules/nixos/development.nix, which keeps Docker. Containers
# and VMs got lumped together there because both are "virtualisation", but
# they're different enough in cost and audience to be worth separate switches:
# libvirtd brings a daemon, a bridge interface, swtpm and a GUI app, and a
# host that wants containers usually doesn't want all of that too.
#
# **Not imported by default.** Add it to `hosts/<host>/configuration.nix` on
# the machines that actually run guests.
#
# joshr's membership of the `libvirtd` group follows this import
# automatically — modules/nixos/users.nix keys it off
# `config.virtualisation.libvirtd.enable` rather than naming the group
# outright, because naming a group nothing declares fails activation.
{
  # Single GPU passthrough rides along, switched off. It is a libvirt hook and
  # nothing else, so it has no meaning without libvirtd and no cost until
  # `local.virtualisation.singleGpuPassthrough.enable` is set — which is why
  # it comes in here rather than being a third import for a host to remember.
  imports = [ ./gpu-passthrough.nix ];

  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      package = pkgs.qemu_kvm;

      # Keep the QEMU processes unprivileged. The default is already false;
      # stated because the failure mode of the other setting is a guest
      # escape being a root escape.
      runAsRoot = false;

      # Software TPM. The other half of what Windows 11 refuses to install
      # without, and harmless for guests that don't ask.
      swtpm.enable = true;
    };
  };

  # virt-manager as the GUI. The NixOS module does more than install it — it
  # also enables the dconf settings the app stores its connection list in,
  # which is why it's a `programs.*` option rather than a package.
  programs.virt-manager.enable = true;

  # USB redirection from the host into a guest, which is what makes a
  # passed-through keyboard, YubiKey or flash drive work in virt-manager.
  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    virtiofsd # share a host directory into a guest without NFS
    spice-gtk # the client side of the SPICE console
  ];
}
