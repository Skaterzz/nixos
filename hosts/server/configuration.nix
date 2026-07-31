{ ... }:

# Headless server.
#
#   sudo nixos-rebuild switch --flake .#server
#
# The odd one out: no desktop, no display manager, no niri, no Plasma, no
# gaming, no NVIDIA. Just base.nix, boot.nix, users.nix and the two modules
# that give this machine its job — so `joshr` and `root` get the same fish +
# starship shell they have everywhere else and nothing graphical follows them
# in. The home profile is home/joshr/server.nix, which is shaped like root's
# rather than built on the desktop base.
#
# Reach it over SSH — base.nix already enables sshd with password auth off,
# so **put a key in place before the first boot** or the only way in is a
# physical console. Tailscale is enabled there too, and still needs
# `tailscale up` once by hand.
{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/cron.nix
    ../../modules/nixos/users.nix

    # Development tooling: direnv, Docker, libvirtd/QEMU/virt-manager, and
    # the nix settings per-project dev shells need.
    #
    # Imported rather than commented out here, unlike the desktops — a
    # headless box is where containers and a remote `nix develop` are the
    # point. Comment it out if this machine only ever runs the cron jobs
    # below; it costs two daemons and a bridge interface.
    ../../modules/nixos/development.nix
  ];

  networking.hostName = "server";

  # No theming to carry and no wallpaper to draw, so the boot menu doesn't
  # need limine — systemd-boot is the most boring, best-tested option on a
  # UEFI machine, and this one is likely to reboot unattended.
  local.boot.loader = "systemd-boot";

  # ---------------------------------------------------------------------
  # Cron
  # ---------------------------------------------------------------------
  #
  # See modules/nixos/cron.nix for the option, and "Scheduled jobs" in the
  # README for the reasoning. Three things worth remembering before adding to
  # the list:
  #
  #   * Bare command names work. nixpkgs' cron module puts all of
  #     `environment.systemPackages` on PATH and runs jobs under bash, so the
  #     usual "write absolute paths" advice doesn't apply here. Only a tool
  #     that *isn't* installed system-wide needs `local.cron.path`.
  #   * `%` means "newline" in a crontab. `date +%F` has to be `date +\%F`.
  #   * A job missed while the machine was off never runs. If that matters
  #     for a particular job, write it as a systemd timer with
  #     `Persistent = true` instead — the two coexist fine.
  #
  # Schedules are in the system timezone (`time.timeZone`, America/Detroit),
  # not UTC.
  local.cron = {
    enable = true;

    jobs = [
      {
        name = "nix-gc";
        description = "Trim the store beyond what base.nix's weekly GC keeps";
        schedule = "30 3 * * 0";
        command = "nix-collect-garbage --delete-older-than 30d";
      }

      {
        name = "nix-optimise";
        description = "Hard-link identical files in the store";
        schedule = "0 4 * * 0";
        command = "nix-store --optimise";
      }

      {
        name = "journal-vacuum";
        description = "Cap the journal so a chatty unit can't fill /var";
        schedule = "15 4 * * *";
        command = "journalctl --vacuum-time=30d --vacuum-size=500M";
      }
    ];
  };

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "24.11";
}
