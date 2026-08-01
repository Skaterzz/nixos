{ config, lib, pkgs, niriTheming, ... }:

# Emoji picker, on `Mod+.` — the shortcut Windows uses, and the reason this
# exists at all.
#
# Three pieces:
#
#   the list     built here from the Unicode Consortium's own emoji-test.txt,
#                which `pkgs.unicode-emoji` already carries.
#   the picker   `bemoji`, which sorts by what you actually use, hands the
#                list to a menu program and acts on what comes back.
#   the menu     wofi, the same one the launcher and every other menu in this
#                session uses, styled from the active theme.
#
# The glyphs themselves are Microsoft's Fluent Emoji; see
# modules/nixos/emoji.nix, which is also what makes them show up this way in
# Firefox, kitty and everywhere else.
let
  inherit (niriTheming) activeDir;

  # bemoji's emoji list.
  #
  # bemoji normally builds this itself on first run, by curling
  # unicode.org/Public/emoji/latest/emoji-test.txt into ~/.local/share/bemoji.
  # That is the one thing about it that doesn't belong on this machine: it
  # makes a keybind depend on the network, on a "latest" URL that moves, and
  # on mutable state no rebuild can reproduce. So the same transformation runs
  # at build time instead, against the pinned copy in `pkgs.unicode-emoji`, and
  # BEMOJI_DB_LOCATION points at the result.
  #
  # Pointing that variable at a store path also settles the download question
  # for good. bemoji only fetches when its database directory comes back empty
  # from `find -maxdepth 0 -type d -empty`, and this one is never empty — the
  # check below fails the build rather than let it be.
  #
  # emoji-test.txt lists every emoji three ways (fully-qualified, minimally-
  # qualified, unqualified) plus the lone components; only fully-qualified is
  # wanted, or the list comes out with three near-identical rows per emoji.
  # Each of those lines looks like
  #
  #   1F468 200D 1F9B0  ; fully-qualified  # 👨‍🦰 E11.0 man: red hair
  #
  # and bemoji wants `<emoji><space><description>`, so the sed keeps the glyph
  # and the name and drops the codepoints and the `E11.0` version stamp.
  emojiDb = pkgs.runCommand "bemoji-emoji-db" { } ''
    mkdir -p "$out"

    sed -n -e 's/^.*; fully-qualified *# \(\S\+\) E[0-9.]\+ \(.*\)$/\1 \2/p' \
      ${pkgs.unicode-emoji.emoji-test}/share/unicode/emoji/emoji-test.txt \
      > "$out/emojis.txt"

    # A silently empty list would leave an empty picker on the keybind, so a
    # format change upstream should stop the build here instead. The real
    # count is a few thousand; anything under a thousand means the pattern
    # above no longer matches what Unicode ships.
    count=$(wc -l < "$out/emojis.txt")
    if [ "$count" -lt 1000 ]; then
      echo "only $count emoji parsed out of emoji-test.txt — the format changed" >&2
      exit 1
    fi
  '';

  # Frequency history. bemoji appends every pick here and floats the most-used
  # to the top of the list next time, which is the behaviour that makes the
  # Windows picker feel fast. Deliberately outside the store: it is the one
  # part of this that is supposed to change.
  #
  # bemoji's `get_most_recent` touches this file without creating its parent,
  # so the directory has to exist before it runs — hence the mkdir in the
  # picker below.
  historyDir = "${config.home.homeDirectory}/.local/state/bemoji";

  # Type the chosen emoji into whatever had focus.
  #
  # Wrapped rather than left to bemoji's built-in `wtype -s 30` for the sleep.
  # The typing starts the moment wofi exits, and niri needs a moment to hand
  # focus back to the window underneath — without the pause the keystrokes can
  # land while nothing is focused yet, and the emoji goes nowhere.
  #
  # `--` because wtype otherwise reads a leading `-` as an option. No emoji
  # starts with one, but the guard costs nothing.
  emojiType = pkgs.writeShellApplication {
    name = "emoji-type";
    runtimeInputs = with pkgs; [
      coreutils
      wtype
    ];
    text = ''
      [ "$#" -ge 1 ] || { echo "usage: emoji-type <text>" >&2; exit 2; }

      sleep 0.15
      exec wtype -s 20 -- "$1"
    '';
  };

  # wofi's invocation, assembled here because bemoji takes it as one string in
  # BEMOJI_PICKER_CMD and `eval`s it.
  #
  # Wider and taller than the launcher: rows are `😀 grinning face`, and the
  # point of the description is that it is searchable, so `--insensitive` plus
  # a line long enough to read it matters more here than compactness.
  #
  # markup and images are both turned off. They are on globally in
  # notifications.nix for the launcher's sake, and here they would only give
  # Pango and wofi's `img:` syntax a chance to misread an emoji name.
  pickerCmd = lib.concatStringsSep " " [
    "wofi --dmenu"
    ''--prompt "Emoji"''
    "--insensitive"
    "--width 680"
    "--height 520"
    "--lines 10"
    ''--style "${activeDir}/wofi-emoji.css"''
    "--define=allow_markup=false"
    "--define=allow_images=false"
  ];

  # What Mod+. runs.
  #
  # Both actions, in this order: the emoji goes on the clipboard first, then
  # gets typed. Typing alone would be the closer copy of Windows, but it
  # depends on the focused window accepting synthetic keystrokes — most do,
  # some don't — and when it doesn't there is nothing to show for the
  # keypress. Copying first means the fallback is already in place by the time
  # typing is attempted, and cliphist keeps the selection it displaced (see
  # clipboard.nix), so nothing is actually lost.
  #
  # `-n` drops the trailing newline bemoji would otherwise print. It matters
  # for the clipboard half — pasting would carry a stray line break — and not
  # at all for the typing half, which strips it anyway.
  emojiPicker = pkgs.writeShellApplication {
    name = "emoji-picker";
    runtimeInputs = with pkgs; [
      bemoji
      coreutils
      wl-clipboard
      wofi
    ];
    text = ''
      mkdir -p "${historyDir}"

      export BEMOJI_DB_LOCATION="${emojiDb}"
      export BEMOJI_HISTORY_LOCATION="${historyDir}"
      export BEMOJI_TYPE_CMD="${lib.getExe emojiType}"
      export BEMOJI_PICKER_CMD=${lib.escapeShellArg pickerCmd}

      # Escape closes wofi with a non-zero status. That's a cancel, not a
      # failure, and `set -e` would otherwise make the keybind exit non-zero.
      bemoji -n -c -t || exit 0
    '';
  };
in
{
  # `emoji-type` is deliberately not here. It is an implementation detail the
  # picker reaches by store path, so it stays in the closure either way, and
  # there is no reason for it to be a command you can run.
  home.packages = [ emojiPicker ];

  _module.args.niriEmoji = {
    inherit emojiPicker;
  };
}
