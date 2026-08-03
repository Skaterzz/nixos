{ ... }:

# Headless server with an NVIDIA card in it.
#
#   sudo nixos-rebuild switch --flake .#server-nvidia
#
# hosts/server/ with a GPU, and that is the whole difference: same base, same
# boot loader, same cron hygiene, same shell-only home profile, plus
# modules/nixos/nvidia-server.nix — the driver, nvidia-persistenced, the
# container toolkit, and the nvidia-patch overlay that takes the NVENC
# session cap and the NvFBC lock off a GeForce card.
#
# It is a second host rather than an option on `server` because the two are
# different machines. The one that has a card gets a driver, a local driver
# build on every kernel bump, and a `hardware-configuration.nix` of its own;
# the one that doesn't shouldn't carry any of that on the off chance.
#
# What it is for: transcoding (Jellyfin, Plex, Frigate, a stack of ffmpeg
# jobs), CUDA work, and containers that ask for `--gpus all`. None of those
# services are configured here — this is the machine they would run on, and
# they go in this file or in a module of their own once there is one to add.
#
# Reach it over SSH — base.nix enables sshd with password auth off, so **put
# a key in place before the first boot** or the only way in is a physical
# console. Tailscale is enabled there too and still needs `tailscale up` once
# by hand.
{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/cron.nix
    ../../modules/nixos/server-users.nix

    # The card. See the header of that file for what the patch does, what it
    # costs, and how to tell whether it took.
    #
    # NOT ../../modules/nixos/nvidia.nix — that is the desktop driver, and
    # importing both would leave two definitions of
    # `hardware.nvidia.package`.
    ../../modules/nixos/nvidia-server.nix

    # Development tooling: direnv, Docker, and the nix settings per-project
    # dev shells need.
    #
    # Docker is the reason it is here rather than commented out, as it is on
    # the desktops: `local.nvidia.containerToolkit` follows
    # `virtualisation.docker.enable`, so this import is also what makes
    # `docker run --gpus all` work. Drop it and the card is still there for
    # anything running directly on the host.
    ../../modules/nixos/development.nix

    # NOT imported: ../../modules/nixos/ai.nix
    #
    # It would fit — ollama on this card is the obvious use for it, and its
    # comment about the server having no GPU stops being true here. Left out
    # because it is a decision rather than a default: `local.ai.openclaw` is
    # an agent with a shell, and `linger` on a machine nobody logs into means
    # it runs unattended. Import it and set `local.ai` when that is wanted;
    # "Local AI" in MANUAL.md is the long version.
  ];

  networking.hostName = "jrh-gpu-01";

  # No theming to carry and no wallpaper to draw, so the boot menu doesn't
  # need limine — same reasoning as hosts/server/configuration.nix, and the
  # same answer.
  local.boot.loader = "systemd-boot";

  # ---------------------------------------------------------------------
  # The card
  # ---------------------------------------------------------------------
  #
  # Every option here is at its default; they are written out because these
  # are the two a different machine is most likely to have to change, and a
  # wrong `open` produces a driver that doesn't load rather than a driver
  # that complains. The rest — `local.nvidia.patch.*`, `containerToolkit`,
  # `persistenced` — are in modules/nixos/options.nix.
  local.nvidia = {
    # NVIDIA's longest-supported branch, and old enough that nvidia-patch has
    # certainly published offsets for it. "latest" is the desktop's choice
    # and regularly outruns the patch.
    driver = "legacy_580"; # This is for GTX 1060

    # Turing (RTX 20xx, GTX 16xx) or newer. **Set this to false on Pascal** —
    # P4, P40, GTX 10xx, which is most of what ends up in a box like this —
    # since those have no open kernel module and the build produces a driver
    # that will not load.
    open = false;

    # If this machine's job is serving more concurrent encodes than an
    # unpatched card allows, this turns "the driver quietly lost its patch"
    # from a warning into a failed rebuild:
    #
    #   patch.required = true;
  };

  # ---------------------------------------------------------------------
  # Cron
  # ---------------------------------------------------------------------
  #
  # The same three housekeeping jobs as hosts/server/configuration.nix, which
  # is where the notes on writing them live — bare command names work, `%`
  # has to be escaped, and a job missed while the machine was off never runs.
  #
  # Schedules are in the system timezone (America/Detroit), not UTC.
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
  system.stateVersion = "26.11";
}
