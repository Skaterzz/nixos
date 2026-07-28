{ ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      name = "FiraCode Nerd Font Mono";
    };

    settings = {
      cursor_trail = "15";
      enable_audio_bell = "no";
      window_padding_width = "15";
      confirm_os_window_close = "0";
      background_opacity = "0.9";
      background_blur = "1";
      linux_display_server = "wayland";
    };

    # zenwritten_dark theme (mcchrish/zenbones.nvim), inlined verbatim instead
    # of `include current-theme.conf`.
    extraConfig = ''
      foreground                      #BBBBBB
      background                      #191919
      selection_foreground            #BBBBBB
      selection_background            #404040
      cursor                          #C9C9C9
      cursor_text_color               #191919
      active_tab_foreground           #BBBBBB
      active_tab_background           #65435E
      inactive_tab_foreground         #BBBBBB
      inactive_tab_background         #303030
      # black
      color0 #191919
      color8 #3D3839
      # red
      color1 #DE6E7C
      color9 #E8838F
      # green
      color2  #819B69
      color10 #8BAE68
      # yellow
      color3  #B77E64
      color11 #D68C67
      # blue
      color4  #6099C0
      color12 #61ABDA
      # magenta
      color5  #B279A7
      color13 #CF86C1
      # cyan
      color6  #66A5AD
      color14 #65B8C1
      # white
      color7  #BBBBBB
      color15 #8E8E8E
    '';
  };
}
