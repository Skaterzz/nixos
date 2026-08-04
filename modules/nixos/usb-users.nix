{ config, lib, pkgs, ... }:

# Accounts on the portable stick: joshr, and nobody else.
#
# The third users module, after ./users.nix (the shared machines: joshr,
# amandak, sabom) and ./server-users.nix (headless: joshr, no session groups).
# It is a separate file rather than an option on either because "who exists on
# this machine" is not a knob — a list of accounts merges by union, so a host
# that imported ./users.nix could add people but could never take one away.
# One file per answer is the only shape that lets a host say *only*.
#
# Only matters more here than on the other hosts. This one auto-logs in (see
# hosts/usb/configuration.nix), so the account that exists is the account the
# machine hands to whoever plugs the stick in. A second name in this file
# would be a second home directory riding around in a pocket.
#
# root still exists — every NixOS machine has one, and this is not the file
# that could change that. It has no password on any host here, so it is
# reachable through joshr's sudo and not by logging in as root.
let
  # Same set as ./users.nix. `video` and `input` are what a session needs and
  # ./server-users.nix leaves out; this host has a desktop, so it wants them.
  #
  # `docker` and `libvirtd` follow their daemons rather than being assumed,
  # because naming a group nothing declares fails activation. Neither is
  # imported by hosts/usb at the moment; they are kept so that uncommenting
  # modules/nixos/development.nix there is the whole change.
  #
  # `disk` is deliberately not here, and that is worth stating on the one host
  # built for disk work. Membership would hand every process in the session
  # raw read/write on every block device, which is root over the machine by
  # another name. The partition editors don't want it either — they ask polkit
  # and get a privileged helper for the one operation, which is the same
  # access with a prompt in front of it. See modules/nixos/disk-managements.nix.
  sessionGroups =
    [
      "networkmanager"
      "video"
      "input"
    ]
    ++ lib.optional config.virtualisation.docker.enable "docker"
    ++ lib.optional config.virtualisation.libvirtd.enable "libvirtd";
in

{
  # `programs.fish.enable` in base.nix is what puts fish in /etc/shells, which
  # is required before it can be set as a login shell here.
  users.users.root.shell = pkgs.fish;

  users.users.joshr = {
    isNormalUser = true;
    description = "Josh Randall";
    shell = pkgs.fish;

    extraGroups = [ "wheel" ] ++ sessionGroups;

    # OpenSSH Public Keys
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHhGu88k2qhLbZRr2eGl9rPGV22Z4SPpqHSp/oQ1H5kc"
    ];

    # Only applied when the account is first created, so that a fresh install
    # can actually log in. Change it immediately after first login:
    #   passwd
    # Once changed, the new password sticks (users.mutableUsers defaults to
    # true), and editing this line has no further effect.
    #
    # On this host that first login is automatic, so the password is not what
    # gets you a desktop — it is what `sudo` and the lock screen ask for. Both
    # of those are the whole of the security on a device that can be picked up
    # and walked off with, so changing it is not optional here the way it
    # nearly is on a machine that sits on a desk.
    initialPassword = "changeme";
  };
}
