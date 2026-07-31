{ pkgs, ... }:

# Clipboard history.
#
# Two halves, and they are separate on purpose:
#
#   the store   `cliphist`, run by home-manager as two `wl-paste --watch`
#               user services (one for text, one for images). Wayland has no
#               clipboard manager in the compositor — a copied selection lives
#               in the *source* client and disappears when it exits — so
#               something has to sit on the socket and keep a copy. That is
#               all this daemon does; it has no UI.
#
#   the picker  the script below, bound to a key in niri.nix. It lists the
#               history through wofi, decodes whatever was chosen and puts it
#               back on the clipboard.
#
# cliphist stores the *decoded* bytes and hands back an id-prefixed preview
# line, which is why the picker pipes its choice straight back through
# `cliphist decode` rather than trying to parse the preview. Binary entries
# (images) show as `[[ binary data … ]]`; decoding one puts the real image
# back on the clipboard, so a paste into an image-aware app still works.
let
  # wofi is already themed — home/joshr/niri/notifications.nix points its
  # `style` key at the active theme — so nothing here has to know about
  # colours. The one thing worth overriding is the width: history lines are
  # long, and the launcher's 620px cuts most of them off.
  clipboardHistory = pkgs.writeShellApplication {
    name = "clipboard-history";
    runtimeInputs = with pkgs; [
      cliphist
      wofi
      wl-clipboard
    ];
    text = ''
      # A cancelled picker (Escape) exits non-zero and prints nothing; that
      # is not an error, so don't let `set -e` turn it into one.
      choice="$(cliphist list | wofi --dmenu \
                  --prompt "Clipboard" \
                  --insensitive \
                  --width 900 \
                  --height 500 \
                  --lines 12)" || exit 0

      [ -n "$choice" ] || exit 0

      printf '%s\n' "$choice" | cliphist decode | wl-copy
    '';
  };

  # Wipe the history. Not bound to a key — this is the sort of thing you want
  # to have to type — but it is on PATH, and the picker is useless for
  # clearing one entry, so both jobs live here.
  clipboardWipe = pkgs.writeShellApplication {
    name = "clipboard-wipe";
    runtimeInputs = with pkgs; [
      cliphist
      wl-clipboard
      libnotify
    ];
    text = ''
      cliphist wipe
      # The daemon would otherwise re-store whatever is currently held the
      # next time anything reads the clipboard, putting one entry straight
      # back into the history you just emptied.
      wl-copy --clear

      notify-send -a clipboard -i edit-clear \
        "Clipboard" "History cleared" || true
    '';
  };
in
{
  services.cliphist = {
    enable = true;

    # Images too — an entry costs a screenshot's worth of disk rather than a
    # line's, which is why the item cap below is lower than the default 500.
    allowImages = true;

    # Named rather than left to `wayland.systemd.target`'s default, matching
    # waybar and swayidle: niri starts the session and everything graphical
    # in this config hangs off graphical-session.target.
    systemdTargets = [ "graphical-session.target" ];

    extraOptions = [
      # Deduplicate against the last 20 entries rather than the default 10.
      # Copying the same snippet a few times while moving between files is
      # normal and shouldn't push the rest of the history out.
      "-max-dedupe-search"
      "20"
      "-max-items"
      "300"
    ];
  };

  home.packages = [
    clipboardHistory
    clipboardWipe
  ];

  _module.args.niriClipboard = {
    inherit clipboardHistory clipboardWipe;
  };
}
