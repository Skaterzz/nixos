{ config, lib, pkgs, ... }:

{
  # `programs.fish.enable` in base.nix is what puts fish in /etc/shells, which
  # is required before it can be set as a login shell here.
  users.users.root.shell = pkgs.fish;

  users.users.joshr = {
    isNormalUser = true;
    description = "Joshua Randall";
    shell = pkgs.fish;

    # `docker` and `libvirtd` are conditional because the groups only exist
    # when their daemons do, and those live in modules/nixos/development.nix,
    # which is commented out per host. Naming a group that nothing declares
    # fails activation with "group does not exist" — so the membership
    # follows the daemon rather than assuming it.
    extraGroups =
      [
        "wheel"
        "networkmanager"
        "video"
        "input"
      ]
      ++ lib.optional config.virtualisation.docker.enable "docker"
      ++ lib.optional config.virtualisation.libvirtd.enable "libvirtd";


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
