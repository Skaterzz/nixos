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
  # Removing entries
  # ----------------
  # Two ways, because wofi gives no way to put a button on a row:
  #
  #   the Delete key   `key_custom_0`, which makes wofi exit with status 10.
  #                    The entry under the cursor is removed and the picker
  #                    reopens, so several can go in a row.
  #
  #   a "Delete entries…" row  at the top of the list, which switches the
  #                    picker into a mode where Enter (or a mouse click)
  #                    removes instead of copies. That is the discoverable
  #                    version, and the only one reachable with a mouse.
  #
  # Backspace is deliberately *not* bound. wofi's dmenu mode puts the cursor
  # in a search box, and Backspace is how you correct what you typed there —
  # binding it here would make the history impossible to search. Delete is
  # free, which is why it's the one. To add another (`Shift-BackSpace`, say),
  # it's one more `--define=key_custom_1=…` below plus its exit code in the
  # case at the bottom of the loop.
  #
  # `--define` rather than `programs.wofi.settings`, because that file is
  # shared with the launcher and the theme, wallpaper and session menus:
  # binding Delete globally would arm a delete exit code in all of them.
  #
  # wofi is already themed — home/joshr/niri/notifications.nix points its
  # `style` key at the active theme — so nothing here has to know about
  # colours. The overrides that matter are the width (history lines are long,
  # and the launcher's 620px cuts most of them off) and turning markup and
  # image syntax off: clipboard contents are arbitrary text, and a snippet
  # containing `<b>` or a leading `img:` would otherwise be interpreted
  # rather than shown.
  clipboardHistory = pkgs.writeShellApplication {
    name = "clipboard-history";
    runtimeInputs = with pkgs; [
      cliphist
      wofi
      wl-clipboard
    ];
    text = ''
      # The two action rows. Neither can collide with a real entry: cliphist
      # prefixes every line it prints with a numeric id and a tab.
      delete_row="✕  Delete entries…"
      back_row="←  Back to copying"

      mode=copy

      while :; do
        if [ "$mode" = copy ]; then
          header="$delete_row"
          prompt="Clipboard"
        else
          header="$back_row"
          prompt="Clipboard — deleting"
        fi

        rc=0
        choice="$( { printf '%s\n' "$header"; cliphist list; } | wofi --dmenu \
                     --prompt "$prompt" \
                     --insensitive \
                     --width 900 \
                     --height 500 \
                     --lines 12 \
                     --define=key_custom_0=Delete \
                     --define=allow_markup=false \
                     --define=allow_images=false )" || rc=$?

        # Escape, or a delete keypress with nothing under the cursor. Either
        # way there is nothing to act on and no reason to reopen — without
        # this, cancelling out of the delete key would reopen forever.
        [ -n "$choice" ] || exit 0

        # The action rows are not entries. Enter on one switches mode; the
        # delete key on one does nothing at all.
        case "$choice" in
          "$delete_row")
            if [ "$rc" = 0 ]; then mode=delete; fi
            continue
            ;;
          "$back_row")
            if [ "$rc" = 0 ]; then mode=copy; fi
            continue
            ;;
        esac

        # Anything that isn't one of cliphist's `<id><tab><preview>` lines is
        # a search string that matched nothing. Reopen rather than act on it.
        case "$choice" in
          [0-9]*) ;;
          *) continue ;;
        esac

        # rc 10 is key_custom_0 — the Delete key. Note wofi documents that as
        # setting the exit code rather than exiting on the spot, so on 1.5.3
        # it takes effect when the picker is next dismissed; either way the
        # entry under the cursor is the one that goes.
        if [ "$rc" != 0 ] || [ "$mode" = delete ]; then
          printf '%s\n' "$choice" | cliphist delete || true
          continue
        fi

        # Piped straight through rather than captured in a variable: an image
        # entry decodes to binary, and a command substitution would mangle it
        # — NUL bytes dropped, trailing newlines eaten. `|| true` because an
        # entry the daemon has since dropped is a failed decode, not a reason
        # to exit non-zero from a keybind.
        printf '%s\n' "$choice" | cliphist decode | wl-copy || true
        exit 0
      done
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
