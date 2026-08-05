{ ... }:

# joshr's home profile on the stick, niri session.
#
# The portable subset of ./laptop-niri.nix. Everything dropped was dropped for
# one of two reasons — it costs disk space the stick doesn't have, or it
# assumes hardware the stick can't count on — and each is named below rather
# than simply missing, so putting one back is a line rather than an
# archaeology exercise.
{
  imports = [
    ./home.nix
    ./niri
    ./niri/privacy.nix
    ./kitty.nix
    ./ranger.nix
    ./firefox.nix
    ./browser.nix

    # Kept in spite of being the heaviest thing on this list, because two of
    # the things in it are structural rather than applications. It writes the
    # XDG applications.menu that KService needs before it will index desktop
    # entries at all — Plasma ships one and a standalone niri session doesn't,
    # so without this the launcher and the File Associations panel come up
    # empty — and it owns the image/video/audio defaults that
    # modules/nixos/default-apps.nix leaves to the session. Prune its
    # `home.packages` list if the stick fills up; that is the part that is
    # only applications.
    ./desktop-apps.nix

    # No ./displays/*.nix, and that is the point rather than an omission.
    # Those files set `local.niri.outputs`, which pins a connector name and a
    # mode — right on a machine whose monitors don't change, and wrong on
    # every machine this one is plugged into. The option defaults to an empty
    # list, which is niri's auto-detect: it takes each output's preferred mode
    # and lays them out left to right.
    #
    # `local.niri.workspaceOutput` is left null for the same reason. Pinning
    # the numbered workspaces to a named display would strand them on a
    # display that isn't there.

    # NOT imported: ./wallhaven.nix. It downloads twenty wallpapers at
    # activation and again at every login, which is a lot of writes to flash
    # and a lot of network for a machine that is frequently booted somewhere
    # without either. The dotfiles' own collection is still linked into
    # ~/.local/share/wallpapers by ./home.nix, so the picker (Mod+Ctrl+W) is
    # not empty — it just doesn't grow.
    #
    # NOT imported: ./office.nix, ./obs.nix, ./content-creation.nix,
    # ./gaming.nix. Gigabytes each, and none of them is what a stick is for.
    #
    # NOT imported: ./vscode.nix — note that home/joshr/niri/default.nix
    # imports ./niri/vscode.nix, which is the session's *theming* of it and
    # not the editor. Nothing installs VS Code here. `vim` from base.nix is
    # `$EDITOR` and kate arrives with ./desktop-apps.nix, which between them
    # cover editing a config file on a machine you are fixing; `nix run
    # nixpkgs#vscode` is the one-off if the real thing is wanted.
    #
    # NOT imported: ./spicetify.nix. Spotify, patched — a from-source theme
    # build for a machine with no speakers of its own.
  ];

  local.niri.randomLockGreetings = true;
}
