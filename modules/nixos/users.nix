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
    # can actually log in at SDDM. Change it immediately after first login:
    #   passwd
    # Once changed, the new password sticks (users.mutableUsers defaults to
    # true), and editing this line has no further effect.
    initialPassword = "changeme";
  };

  # An account kept for the day it is wanted again. home/raiden/ is still
  # there and still shaped like the two live ones below; uncommenting this
  # block and the `raiden = …` lines in flake.nix is the whole of bringing it
  # back. home/delta/ is the same, for the block further down.
  # users.users.raiden = {
  #   isNormalUser = true;
  #   description = "Samuel Hunt";
  #   shell = pkgs.fish;

  #   # No `wheel`: this account can use the machine but not administer it,
  #   # which is the difference between it and joshr. `nixos-rebuild` and
  #   # everything else behind sudo therefore needs joshr. Add "wheel" to the
  #   # list to change that.
  #   extraGroups = sessionGroups;

  #   # No authorized keys — the one above is joshr's. Add this account's own
  #   # public key here to reach it over SSH; base.nix has password auth off, so
  #   # until then it is a console/greeter login only.

  #   # Same caveat as joshr's above: first login only, then `passwd`.
  #   initialPassword = "changeme";
  # };

  # The other two accounts, both wearing joshr's profile — see home/amandak/
  # and home/sabom/, whose entrypoints import joshr's for the same host. That
  # includes the desktop shell, so on the niri hosts these sessions are the
  # same noctalia as joshr's, each reading its own ~/.config/noctalia and
  # writing its own ~/.local/state/niri-theme.
  #
  # Declaring an account here is only half of it: without a matching entry in
  # that host's `homeModules` in flake.nix the account still exists and can
  # still log in, to a session with no home-manager profile behind it at all.
  #
  # joshr stays the primary user either way. `local.desktop.primaryUser` is
  # unset here, so the "joshr" default in modules/nixos/options.nix stands, and
  # that is what the login screen and the boot menu take their theme and
  # wallpaper from and what the OpenRGB resume service runs as. Nothing about
  # these two is machine-wide.
  users.users.amandak = {
    isNormalUser = true;
    description = "Amanda Kast";
    shell = pkgs.fish;

    # No `wheel`: this account can use the machine but not administer it,
    # which is the difference between it and joshr. `nixos-rebuild` and
    # everything else behind sudo therefore needs joshr. Add "wheel" to the
    # list to change that.
    extraGroups = sessionGroups;

    # No authorized keys — the one above is joshr's. Add this account's own
    # public key here to reach it over SSH; base.nix has password auth off, so
    # until then it is a console/greeter login only.

    # Same caveat as joshr's above: first login only, then `passwd`.
    initialPassword = "changeme";
  };

  users.users.sabom = {
    isNormalUser = true;
    description = "Michael Sabo";
    shell = pkgs.fish;

    # No `wheel`: this account can use the machine but not administer it,
    # which is the difference between it and joshr. `nixos-rebuild` and
    # everything else behind sudo therefore needs joshr. Add "wheel" to the
    # list to change that.
    extraGroups = sessionGroups;

    # No authorized keys — the one above is joshr's. Add this account's own
    # public key here to reach it over SSH; base.nix has password auth off, so
    # until then it is a console/greeter login only.

    # Same caveat as joshr's above: first login only, then `passwd`.
    initialPassword = "changeme";
  };
  #  users.users.delta = {
  #   isNormalUser = true;
  #   description = "Donovan Romaya";
  #   shell = pkgs.fish;

  #   # No `wheel`: this account can use the machine but not administer it,
  #   # which is the difference between it and joshr. `nixos-rebuild` and
  #   # everything else behind sudo therefore needs joshr. Add "wheel" to the
  #   # list to change that.
  #   extraGroups = sessionGroups;

  #   # No authorized keys — the one above is joshr's. Add this account's own
  #   # public key here to reach it over SSH; base.nix has password auth off, so
  #   # until then it is a console/greeter login only.

  #   # Same caveat as joshr's above: first login only, then `passwd`.
  #   initialPassword = "changeme";
  # };
}
