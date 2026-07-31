{ config, lib, ... }:

# Scheduled jobs, as actual cronjobs.
#
# `local.cron.jobs` takes a list of attrsets rather than the raw crontab lines
# `services.cron.systemCronJobs` wants, so a job carries a name and a
# description next to its schedule instead of relying on a comment two lines
# up. They're rendered to crontab lines here.
#
# What NixOS already does for you
# -------------------------------
# The nixpkgs cron module writes a header above whatever we contribute:
#
#     SHELL=/nix/store/…-bash/bin/bash
#     PATH=<system.path>/bin:<system.path>/sbin
#     NIX_CONF_DIR=/etc/nix
#
# That matters, because the usual first thing to know about cron — "the
# environment is nearly empty, write absolute paths" — is **not** true here.
# Anything in `environment.systemPackages` is on PATH already, and the shell
# is bash rather than sh. `local.cron.path` below exists only for packages
# that aren't installed system-wide, and it extends that PATH rather than
# replacing it.
#
# `services.cron.mailto` is the module's own option for where job output is
# mailed; see the note at the bottom of this file about why that's usually
# not the answer.
#
# Why cron and not a systemd timer
# --------------------------------
# systemd timers are the more idiomatic NixOS answer and they're better at
# three things: output lands in the journal instead of a mail spool,
# `systemctl list-timers` shows what's actually scheduled, and
# `Persistent = true` runs a job that was missed while the machine was off.
# Cron has none of that.
#
# It was chosen anyway because crontab syntax is what you already know and
# these jobs are the boring kind — backups, cleanups, a fetch on the hour. If
# a job ever *matters* — skipping it silently is a problem, or you'll want to
# know why it failed three days ago — write it as a systemd service and timer
# directly in the host config instead. Nothing stops the two coexisting.
let
  cfg = config.local.cron;

  # user, schedule and command are what cron actually reads; name and
  # description become the comment above the line, so /etc/crontab stays
  # readable.
  renderJob =
    job:
    let
      header = lib.optional (job.description != null) "# ${job.name}: ${job.description}";
    in
    lib.concatStringsSep "\n" (header ++ [ "${job.schedule} ${job.user} ${job.command}" ]);

  # Prepended to the PATH nixpkgs' cron module already set. Written as one
  # more crontab line because cron applies environment assignments in file
  # order — ours comes after theirs, so it has to restate the system profile
  # or every job loses it.
  systemBin = "${config.system.path}/bin:${config.system.path}/sbin";
in
{
  options.local.cron = {
    enable = lib.mkEnableOption "the cron daemon and the jobs in `local.cron.jobs`";

    path = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.rsync pkgs.restic ]";
      description = ''
        Extra packages on PATH for every job, ahead of the system profile.

        Usually unnecessary: NixOS' cron module already puts all of
        `environment.systemPackages` on PATH, so a bare command name resolves
        for anything installed system-wide. Reach for this when a job needs a
        tool that shouldn't be installed for everyone, and use a full store
        path (`''${pkgs.foo}/bin/foo`) if you'd rather not widen PATH at all.
      '';
    };

    jobs = lib.mkOption {
      default = [ ];
      description = ''
        Scheduled jobs, rendered into the system crontab.

        Each entry is one cron line plus a comment. Setting this does not by
        itself start anything — `local.cron.enable` has to be true as well, so
        a host can carry job definitions it hasn't switched on yet.
      '';
      example = lib.literalExpression ''
        [
          {
            name = "docker-prune";
            description = "Reclaim space from stopped containers and dangling images";
            schedule = "30 4 * * 0";
            command = "docker system prune -af";
          }
        ]
      '';
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = ''
                Short identifier, used in the comment above the crontab line.
                Not read by cron itself.
              '';
            };

            description = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "What the job is for. Ends up as a crontab comment.";
            };

            schedule = lib.mkOption {
              type = lib.types.str;
              example = "0 3 * * *";
              description = ''
                Standard five-field crontab schedule: minute, hour,
                day-of-month, month, day-of-week. Cron's `@hourly`, `@daily`,
                `@weekly`, `@monthly` and `@reboot` shorthands work too.

                Interpreted in the system timezone (`time.timeZone` in
                modules/nixos/base.nix), not UTC — so a job scheduled inside
                the DST changeover window either runs twice or not at all.

                A job missed while the machine was off does not run late.
                Cron has no catch-up; if that matters, use a systemd timer
                with `Persistent = true` instead.
              '';
            };

            user = lib.mkOption {
              type = lib.types.str;
              default = "root";
              description = ''
                Account the job runs as. Defaults to root because that's what
                system maintenance needs; anything touching a user's own files
                should name that user instead.
              '';
            };

            command = lib.mkOption {
              type = lib.types.str;
              example = "nix-collect-garbage --delete-older-than 30d";
              description = ''
                The shell command to run, under bash.

                Watch for `%`: in a crontab it means "newline", and everything
                after the first one is fed to the job on stdin rather than
                being part of the command. A literal one — `date +%F` — has to
                be escaped as `date +\%F`.
              '';
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    services.cron = {
      enable = true;

      systemCronJobs =
        lib.optional (cfg.path != [ ]) "PATH=${lib.makeBinPath cfg.path}:${systemBin}"
        ++ map renderJob cfg.jobs;

      # Left at null on purpose. Cron mails a job's output to its user, and
      # with no MTA installed that mail goes nowhere — which is how a job
      # that has been failing for a month stays invisible. Naming an address
      # here doesn't fix that by itself; it needs a working sendmail.
      #
      # `journalctl -u cron` still records what the daemon started and when.
      # For output you actually want to read, redirect it in the command:
      #
      #     … 2>&1 | systemd-cat -t backup
      mailto = lib.mkDefault null;
    };
  };
}
