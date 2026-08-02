{ lib, pkgs, ... }:

# Screen sharing uses Waybar's native PipeWire privacy module. Microphone use
# is separate so the indicator can toggle and reflect the mute state of the
# exact source device each active application has opened.
let
  microphonePrivacy = pkgs.writeShellApplication {
    name = "waybar-microphone-privacy";

    runtimeInputs = with pkgs; [
      jq
      procps
      pulseaudio
    ];

    text = ''
      active_source_ids() {
        pactl --format=json list source-outputs 2>/dev/null |
          jq -c '
            [
              .[]?
              | select((.corked // false) == false)
              | (.properties // {}) as $props
              | select(
                  ((($props["stream.monitor"] // false) | tostring)) != "true"
                )
              | select(
                  (
                    [
                      $props["application.name"] // "",
                      $props["application.process.binary"] // "",
                      $props["media.name"] // "",
                      $props["node.name"] // ""
                    ]
                    | map(tostring | ascii_downcase)
                    | join(" ")
                    | contains("cava")
                  )
                  | not
                )
              | .source
              | select(. != null)
            ]
            | unique
          '
      }

      source_snapshot() {
        pactl --format=json list sources 2>/dev/null
      }

      status() {
        source_ids="$(active_source_ids)"

        if [ -z "$source_ids" ] || [ "$source_ids" = "[]" ]; then
          printf '%s\n' '{"text":""}'
          return
        fi

        sources="$(source_snapshot)"

        if printf '%s' "$sources" |
          jq -e --argjson active "$source_ids" '
            [
              .[]?
              | select(.index as $index | $active | index($index))
            ] as $sources
            | ($sources | length) > 0
              and all($sources[]; .mute == true)
          ' >/dev/null; then
          printf '%s\n' '{"text":"","class":"muted","tooltip":"Active microphone is muted — click to unmute"}'
        else
          printf '%s\n' '{"text":"","class":"active","tooltip":"Microphone is in use — click to mute"}'
        fi
      }

      toggle() {
        source_ids="$(active_source_ids)"

        if [ -z "$source_ids" ] || [ "$source_ids" = "[]" ]; then
          return
        fi

        sources="$(source_snapshot)"

        # If any active source is currently live, mute every active source.
        # Otherwise they are all muted, so unmute them together.
        if printf '%s' "$sources" |
          jq -e --argjson active "$source_ids" '
            any(.[];
              (.index as $index | $active | index($index))
              and (.mute == false)
            )
          ' >/dev/null; then
          target_mute=1
        else
          target_mute=0
        fi

        printf '%s' "$source_ids" |
          jq -r '.[]' |
          while IFS= read -r source_id; do
            pactl set-source-mute "$source_id" "$target_mute"
          done

        pkill --signal RTMIN+10 --exact waybar || true
      }

      case "''${1:-status}" in
        status)
          status
          ;;
        toggle)
          toggle
          ;;
        *)
          printf 'usage: %s {status|toggle}\n' "$0" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  programs.waybar.settings.main = {
    # Keep the native privacy item passive and specific to screen capture.
    privacy = {
      icon-spacing = 0;
      icon-size = 14;
      transition-duration = 0;

      modules = [
        {
          type = "screenshare";
          icon-name = "waybar-recording";
          tooltip = true;
          tooltip-icon-size = 24;
        }
      ];

      ignore-monitor = true;
    };

    "custom/microphone-privacy" = {
      format = "{}";
      return-type = "json";
      exec = "${lib.getExe microphonePrivacy} status";
      interval = 1;
      signal = 10;
      tooltip = true;
      on-click = "${lib.getExe microphonePrivacy} toggle";
    };
  };

  xdg.dataFile."icons/hicolor/scalable/status/waybar-recording.svg".text = ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
      <circle cx="8" cy="8" r="6" fill="#f44336"/>
    </svg>
  '';
}
