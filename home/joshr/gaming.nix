{ ... }:
{
    programs.mangohud = {
    enable = true;
    enableSessionWide = false;
    settings = {
      fps = true;
      frametime = true;
      gpu_stats = true;
      gpu_temp = true;
      cpu_stats = true;
      cpu_temp = true;
      ram = true;
      vram = true;
      horizontal = true;
      time = true;
      time_format = "%H:%M"
    };
  };
}