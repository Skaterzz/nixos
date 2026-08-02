{ config, lib, pkgs, ... }:

let
  # Groups every interactive account on these machines wants.
  #
  # `docker` and `libvirtd` are conditional because the groups only exist
  # when their daemons do, and those are per-host imports —
  # modules/nixos/development.nix for Docker, modules/nixos/virtualization.nix
  # for libvirtd. Naming a group that nothing declares fails activation with
  # "group does not exist" — so the membership follows the daemon rather than
  # assuming it. Keying off the daemon rather than the module is also what
  # lets those two be imported independently.
  #
  # `wheel` is deliberately not in here. It is the one group that isn't about
  # using the machine, so it's named per account below.
  sessionGroups =
    [
      "networkmanager"
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
    # can actually log in at SDDM. Change it immediately after first login:
    #   passwd
    # Once changed, the new password sticks (users.mutableUsers defaults to
    # true), and editing this line has no further effect.
    initialPassword = "changeme";
  };
}
