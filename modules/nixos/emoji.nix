{ lib, pkgs, ... }:

# Microsoft's Fluent Emoji as the system emoji font.
#
# This is the set Windows 11 draws — the same artwork behind Segoe UI Emoji —
# and it is what makes the picker in home/joshr/niri/emoji.nix look like the
# thing `Win+.` opens on Windows rather than like Android.
#
# It is packaged here rather than pulled from nixpkgs because nixpkgs has no
# Fluent Emoji font. Microsoft publishes fluentui-emoji as loose SVG and PNG
# assets, not as a font (the packaging request, nixpkgs#347889, was closed as
# not planned), so the source is tetunori/fluent-emoji-webfont — a build of
# Microsoft's assets into real font files, MIT like the assets themselves.
#
# Pinned to the v0.8.5 commit rather than to `main`, so the hash below stays
# valid when that branch moves.
#
# 87 MB, which is most of what this module costs. The build carries three
# separate colour formats for the same 33k glyphs — CBDT bitmaps (39 MB),
# COLRv1 vectors (5 MB) and OT-SVG (41 MB) — because it is meant to be dropped
# into browsers, where which one is used depends on the engine. Nothing here
# needs all three: FreeType renders the COLRv1 and falls back to the 109px
# bitmap strike. It ships whole anyway, because stripping tables means a
# fonttools pass whose output would have to be trusted sight-unseen, and a
# silently broken emoji font is worse than a large one. `fonttools subset
# --drop-tables=SVG` is the line to add if the size ever becomes the problem.
let
  # v0.8.5.
  rev = "b7fc5ad4ceb3c7d665087040073d4b64490af96f";

  fluent-emoji = pkgs.stdenvNoCC.mkDerivation {
    pname = "fluent-emoji-color";
    version = "0.8.5";

    src = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/tetunori/fluent-emoji-webfont/${rev}/dist/FluentEmojiColor.ttf";
      hash = "sha256-YpLz/5adgA1VSG4BspMkjM2e5xoX5Pl3C0q+oT2crSU=";
    };

    # A bare .ttf, so there is nothing to unpack and no build to run.
    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm444 "$src" "$out/share/fonts/truetype/FluentEmojiColor.ttf"
      runHook postInstall
    '';

    meta = {
      description = "Microsoft Fluent Emoji as a colour font";
      homepage = "https://github.com/tetunori/fluent-emoji-webfont";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  };
in
{
  fonts.packages = [ fluent-emoji ];

  # Make it the emoji font everywhere, not just where something asks for it by
  # name. This is the fontconfig rule that decides which font supplies a
  # character no other font in the requested family covers — which is how
  # nearly every emoji actually gets drawn, since neither Poppins nor FiraCode
  # has any of them.
  #
  # Noto stays behind it as a fallback rather than being dropped. Fluent Emoji
  # is a 2023-era snapshot of Microsoft's set, so anything Unicode has added
  # since would otherwise render as a tofu box; with this order those few fall
  # through to noto-fonts-color-emoji (from modules/nixos/base.nix) and the
  # rest come out Fluent.
  fonts.fontconfig.defaultFonts.emoji = [
    "Fluent Emoji Color"
    "Noto Color Emoji"
  ];
}
