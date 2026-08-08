{ pkgs, ... }:
{
    #home.packages = with pkgs; [

    #];

    # The overlay, and why it shows what it shows.
    #
    # The counters below are not a general-purpose readout — they are chosen
    # so that a session which slowly goes bad names its own cause without
    # alt-tabbing. Each of the three ways this machine loses frames looks
    # different here:
    #
    #   * **the card is full** — `vram` climbing toward the card's total, with
    #     the frame rate falling and not recovering. Something else is holding
    #     video memory; `gaming-doctor` (modules/nixos/gaming.nix) says what.
    #   * **the card is throttling** — `gpu_core_clock` collapsing from its
    #     boost figure to something far below it while `gpu_temp` climbs and
    #     `gpu_power` sits pinned at the limit. That is a case-and-fans
    #     answer, not a configuration one.
    #   * **shaders are being recompiled** — the frame rate holding but
    #     `frametime` spiking, with `gpu_load_change` showing the card going
    #     idle in the gaps. Add `DXVK_HUD=compiler` to a game's launch options
    #     to confirm it, and see "Gaming performance" in MANUAL.md.
    #
    # `horizontal` is deliberate and it is why there is no frametime *graph*
    # here: MangoHud draws graphs only in the vertical layout, so asking for
    # one alongside `horizontal = true` gets a line that is silently never
    # drawn. The frametime number moves enough to see a hitch.
    programs.mangohud = {
    enable = true;
    enableSessionWide = false;
    settings = {
      fps = true;
      frametime = true;
      gpu_stats = true;
      gpu_temp = true;
      # Clocks and power draw: together these are what separates "the card is
      # working hard" from "the card has been told it may not".
      gpu_core_clock = true;
      gpu_mem_clock = true;
      gpu_power = true;
      gpu_load_change = true;
      cpu_stats = true;
      cpu_temp = true;
      ram = true;
      vram = true;
      # System memory the game itself holds. Worth having next to `ram`:
      # video memory spilling into system memory shows up here first.
      procmem = true;
      horizontal = true;
      time = true;
      time_format = "%H:%M";
    };
  };
}
