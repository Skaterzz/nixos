{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# wallhaven.cc's top 20, in ~/.local/share/wallpapers/WallhavenFlake.
#
# *Which* twenty is a flake input. `wallhaven-toplist` (flake.nix) is the
# JSON response of wallhaven's search API, fetched and hashed by Nix like any
# other input, so the selection is pinned in flake.lock: every machine that
# builds this lock file shows the same twenty, and they only move when asked:
#
#     nix flake update --refresh wallhaven-toplist
#
# What that input cannot carry is the images themselves. A flake input is one
# URL locked by one hash, and the twenty image URLs aren't known until the
# JSON has been fetched and read — by which time evaluation is already under
# way, and `pkgs.fetchurl` would need a checksum per image that wallhaven
# doesn't publish anywhere in its API. So the list is declarative and the
# files are not: the script below reads the locked list and downloads what it
# names into a plain directory in $HOME.
#
# That split has consequences worth being explicit about:
#
#   * The directory is not a store path. It is ordinary files, downloaded at
#     activation, and a machine that has had no network since the last
#     `nix flake update` keeps showing the previous twenty until it does.
#   * The directory belongs entirely to this module. Anything in it that the
#     locked listing doesn't name is deleted — that is what keeps "only the
#     top 20" true once the list moves on, and it is also why nothing else
#     should ever put a file in there.
#
# Both desktops pick the new files up on their own: niri's picker globs the
# wallpaper directory (home/joshr/niri/scripts.nix) and Plasma's slideshow is
# pointed at the same tree (home/joshr/plasma.nix).

let
  cfg = config.local.wallhaven;

  # The locked search response — a single JSON file in the store.
  listing = "${inputs.wallhaven-toplist}";

  wallpaperDir = "${config.xdg.dataHome}/wallpapers";
  targetDir = "${wallpaperDir}/WallhavenFlake";

  sync = pkgs.writeShellApplication {
    name = "wallhaven-sync";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      findutils
      gnugrep
      jq
    ];
    text = ''
      listing=${lib.escapeShellArg listing}
      dir=${lib.escapeShellArg targetDir}
      count=${toString cfg.count}

      # A flake input is whatever the URL happened to return, and `nix flake
      # update` would pin a Cloudflare error page as happily as a result set.
      # Checking first is the difference between "nothing changed" and
      # "deleted all twenty because the API had a bad afternoon".
      if ! jq -e '(.data | type) == "array" and (.data | length) > 0' "$listing" > /dev/null 2>&1; then
        echo "wallhaven-sync: $listing is not a wallhaven search response" >&2
        exit 1
      fi

      mkdir -p "$dir"

      wanted="$(mktemp)"
      trap 'rm -f "$wanted"' EXIT

      failures=0

      # This runs inside `nixos-rebuild switch`. A refused connection fails
      # fast, but a network that swallows packets instead of refusing them
      # does not: twenty files, each retrying against a timeout, is an hour
      # of a rebuild appearing to hang. So the whole run gets a budget, and
      # what it doesn't finish it reports and leaves for the next run.
      deadline=$(( $(date +%s) + ${toString cfg.timeout} ))

      while IFS= read -r url; do
        name="''${url##*/}"

        # Every path below is built from this name and this name comes off
        # the network. Upstream's are all wallhaven-<id>.<ext>; anything else
        # is a response we don't understand, not a wallpaper.
        case "$name" in
          wallhaven-*.*) ;;
          *)
            echo "wallhaven-sync: unexpected file name in listing, skipping: $url" >&2
            failures=$((failures + 1))
            continue
            ;;
        esac

        printf '%s\n' "$name" >> "$wanted"

        # The name carries wallhaven's id, so a file that is already here is
        # already the right file: a wallpaper that merely slid from 3rd to
        # 5th place costs nothing to keep.
        if [ ! -e "$dir/$name" ]; then
          if [ "$(date +%s)" -ge "$deadline" ]; then
            echo "wallhaven-sync: out of time at $name; the rest waits for the next run" >&2
            failures=$((failures + 1))
            break
          fi

          if curl --fail --location --silent --show-error \
              --retry 2 --retry-delay 2 --retry-max-time 60 \
              --connect-timeout 15 --max-time 180 \
              --output "$dir/.$name.part" "$url"; then
            mv -f "$dir/.$name.part" "$dir/$name"
          else
            rm -f "$dir/.$name.part"
            echo "wallhaven-sync: could not download $url" >&2
            failures=$((failures + 1))
          fi
        fi
      done < <(jq -r --argjson n "$count" 'limit($n; .data[].path)' "$listing")

      # Prune only once everything wanted is actually present. Pruning after
      # a half-finished download would leave the picker with *fewer*
      # wallpapers than it started with, and the cause would be a network
      # blip rather than anything about the toplist.
      if [ "$failures" -gt 0 ]; then
        echo "wallhaven-sync: run incomplete (see above); leaving $dir as it is" >&2
        exit 1
      fi

      # Everything else goes, including the leftovers of an interrupted run.
      # Paths here are always "$dir/<name>" and $dir is fixed at build time.
      while IFS= read -r path; do
        name="''${path##*/}"
        if ! grep -qxF "$name" "$wanted"; then
          rm -rf "$path"
        fi
      done < <(find "$dir" -mindepth 1 -maxdepth 1)
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    # Also useful by hand: after a `nix flake update` that you don't want to
    # follow with a full rebuild, and to finish the job when a switch ran
    # without network.
    home.packages = [ sync ];

    # One-off transition, and it has to happen before home-manager starts
    # linking. ~/.local/share/wallpapers used to be a single symlink to the
    # dotfiles' wallpaper directory in the store; it is now a real directory
    # of per-file links (home.nix) so that WallhavenFlake/ has somewhere to
    # live. With the old symlink still in place, every wallpaper's target
    # resolves *through* it into a read-only store path, and the linker tries
    # to back up files it cannot move.
    #
    # Nothing is lost by removing it: what it points at is the store.
    home.activation.wallhavenWallpaperDir = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ -L ${lib.escapeShellArg wallpaperDir} ]; then
        # Only ours. A wallpaper directory deliberately symlinked somewhere
        # else — another disk, say — is not this module's to delete.
        if [[ "$(readlink ${lib.escapeShellArg wallpaperDir})" == ${builtins.storeDir}/* ]]; then
          run rm $VERBOSE_ARG ${lib.escapeShellArg wallpaperDir}
        else
          warnEcho "${wallpaperDir} is a symlink outside the store; leaving it, but WallhavenFlake/ has nowhere to go"
        fi
      fi
    '';

    # The sync itself, once the wallpaper directory exists. Never fatal: an
    # offline switch — or one during boot, before the network is up — should
    # not fail the rebuild, it should leave the previous twenty in place.
    home.activation.wallhavenSync = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${sync}/bin/wallhaven-sync \
        || warnEcho "wallhaven-sync failed; ${targetDir} left as it is"
    '';

    # ...and again at login, which is the retry for the case above. Cheap
    # when there is nothing to do: the listing is a local store path and
    # files already downloaded are never fetched twice, so a run that has
    # nothing to fetch touches the network zero times.
    systemd.user.services.wallhaven-wallpapers = {
      Unit.Description = "Sync ~/.local/share/wallpapers/WallhavenFlake with the locked wallhaven listing";
      Service = {
        Type = "oneshot";
        ExecStart = "${sync}/bin/wallhaven-sync";
        # The script keeps itself inside `local.wallhaven.timeout`; this is
        # only here so a curl wedged somewhere the budget can't see still
        # ends up a failed unit rather than a permanently starting one.
        TimeoutStartSec = cfg.timeout + 300;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
