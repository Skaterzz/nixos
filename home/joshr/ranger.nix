{
  config,
  lib,
  pkgs,
  ...
}:

# ranger with previews.
#
# Terminal app, so this is shared by the Plasma and niri sessions.
#
# Image previews use kitty's graphics protocol, which is why
# `preview_images_method` is "kitty" — that only works when ranger is running
# inside kitty (the Mod+E bind and the launcher both do). In another terminal
# images degrade to the text preview rather than breaking.
let
  # Everything scope.sh shells out to. Kept in one list so the script and the
  # package set can't drift apart.
  previewDeps = with pkgs; [
    bat # syntax-highlighted text
    imagemagick # image identify / conversion
    ffmpegthumbnailer # video thumbnails
    poppler-utils # pdftoppm, pdftotext
    mediainfo # audio/video metadata
    atool # archive listings
    odt2txt # opendocument text
    jq # json
    w3m # html to text
    file
  ];

  scope = pkgs.writeShellScript "ranger-scope" ''
    # ranger preview script.
    #   $1 path   $2 width   $3 height   $4 cache-path   $5 preview-images
    #
    # Exit codes ranger understands:
    #   0 success, display stdout
    #   1 no preview
    #   2 plain text
    #   6 display the image at $1 directly
    #   7 display the image ranger already has
    set -o noclobber -o noglob -o nounset -o pipefail

    FILE_PATH="''${1}"
    W="''${2}"
    H="''${3}"
    IMAGE_CACHE_PATH="''${4}"
    PV_IMAGE_ENABLED="''${5}"

    FILE_EXTENSION="''${FILE_PATH##*.}"
    FILE_EXTENSION_LOWER="$(printf %s "$FILE_EXTENSION" | tr '[:upper:]' '[:lower:]')"

    MIMETYPE="$(file --dereference --brief --mime-type -- "$FILE_PATH")"

    case "$FILE_EXTENSION_LOWER" in
      # Archives: list contents.
      a|ace|alz|arc|arj|bz|bz2|cab|cpio|deb|gz|jar|lha|lz|lzh|lzma|lzo|\
      rpm|rz|t7z|tar|tbz|tbz2|tgz|tlz|txz|tZ|tzo|war|xpi|xz|Z|zip|7z|rar)
        atool --list -- "$FILE_PATH" && exit 0
        exit 1
        ;;
      # Structured text.
      json)
        jq --color-output . "$FILE_PATH" && exit 0
        ;;
      odt|ods|odp|sxw)
        odt2txt "$FILE_PATH" && exit 0
        exit 1
        ;;
      htm|html|xhtml)
        w3m -dump "$FILE_PATH" && exit 0
        ;;
    esac

    case "$MIMETYPE" in
      # PDF: first page as an image if previews are on, text otherwise.
      application/pdf)
        if [ "$PV_IMAGE_ENABLED" = 'True' ]; then
          pdftoppm -f 1 -l 1 -scale-to-x 1920 -scale-to-y -1 -singlefile \
            -jpeg -tiffcompression jpeg -- "$FILE_PATH" "''${IMAGE_CACHE_PATH%.*}" \
            && exit 6
        fi
        pdftotext -l 10 -nopgbrk -q -- "$FILE_PATH" - && exit 0
        exit 1
        ;;

      image/*)
        [ "$PV_IMAGE_ENABLED" = 'True' ] && exit 7
        identify -- "$FILE_PATH" && exit 0
        exit 1
        ;;

      video/*)
        if [ "$PV_IMAGE_ENABLED" = 'True' ]; then
          ffmpegthumbnailer -i "$FILE_PATH" -o "$IMAGE_CACHE_PATH" -s 0 -q 5 \
            && exit 6
        fi
        mediainfo "$FILE_PATH" && exit 0
        exit 1
        ;;

      audio/*)
        mediainfo "$FILE_PATH" && exit 0
        exit 1
        ;;

      text/* | */xml | */javascript | */x-shellscript)
        bat --color=always --style=plain --paging=never \
            --terminal-width="$W" -- "$FILE_PATH" && exit 0
        exit 2
        ;;
    esac

    # Fall back to whatever `file` can tell us.
    file --dereference --brief -- "$FILE_PATH" && exit 0
    exit 1
  '';

  # Ranger opens files through its own `rifle` rules rather than through
  # mimeapps.list. Prepend the three forced media handlers, then retain the
  # complete upstream rule set for text, archives, PDFs and everything else.
  rifle = pkgs.runCommand "ranger-rifle.conf" { } ''
    cat > "$out" <<'EOF'
    mime ^image, X, flag f = ${pkgs.kdePackages.gwenview}/bin/gwenview -- "$@"
    mime ^video, X, flag f = ${pkgs.haruna}/bin/haruna -- "$@"
    mime ^audio, X, flag f = ${pkgs.kdePackages.elisa}/bin/elisa -- "$@"

    EOF

    cat ${pkgs.ranger.src}/ranger/config/rifle.conf >> "$out"
  '';
in
{
  programs.ranger = {
    enable = true;

    # Put the preview tools on ranger's own PATH rather than relying on them
    # being installed globally.
    extraPackages = previewDeps;

    settings = {
      preview_files = true;
      preview_directories = true;
      collapse_preview = true;

      # Image previews through kitty's graphics protocol.
      preview_images = true;
      preview_images_method = "kitty";

      use_preview_script = true;
      preview_script = "${scope}";

      # Quality-of-life defaults that pair with previews.
      show_hidden = false;
      draw_borders = "both";
      display_size_in_main_column = true;
      display_size_in_status_bar = true;
      autoupdate_cumulative_size = true;
      vcs_aware = true;
      vcs_backend_git = "local";
      line_numbers = "relative";
      mouse_enabled = true;
      confirm_on_delete = "multiple";
    };
  };

  xdg.configFile."ranger/rifle.conf" = {
    source = rifle;
    force = true;
  };

  # Also make the tools available in the shell — handy independently of
  # ranger, and `bat` in particular is worth having on PATH.
  home.packages = previewDeps;
}
