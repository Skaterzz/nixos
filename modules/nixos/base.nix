{ config, lib, pkgs, ... }:

{
  # Power behaviour that every host wants: no idle suspend while on mains.
  # See modules/nixos/power.nix and local.power.noAutoSleepOnAC.
  imports = [ ./power.nix ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # NVIDIA, Steam, VS Code, Vivaldi, Spotify and Discord are all unfree.
  # This has to be set as a module option so it applies to the system pkgs
  # (and, via home-manager.useGlobalPkgs, to joshr's profile too).
  nixpkgs.config.allowUnfree = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Building the NixOS manual is one of the slower steps of a rebuild and it
  # runs nearly every time. Web docs cover the same ground. Set this back to
  # true if you want `nixos-help` and the offline manual.
  documentation.nixos.enable = false;

  # Defaults to 25; the store is thousands of small fetches, so a higher
  # ceiling helps most on links with latency (which includes a VM going
  # through a host NAT).
  nix.settings.http-connections = 64;

  # The weather widget ported from the dotfiles was configured for Detroit;
  # adjust if this machine lives somewhere else.
  time.timeZone = "America/Detroit";
  i18n.defaultLocale = "en_US.UTF-8";

  # Dates and times are American everywhere: 12-hour clock, month before day.
  #
  # en_US.UTF-8 already formats that way, so this is belt and braces rather
  # than a change — it pins LC_TIME independently of LANG, which is what
  # anything reading the locale (`date`, `ls -l`, GTK/Qt widgets that ask the
  # locale instead of carrying their own format string) actually consults.
  # The clocks with their own format strings — waybar, swaylock, the SDDM
  # greeter, Plasma's panel — are set in their own modules and don't go
  # through this.
  i18n.extraLocaleSettings.LC_TIME = "en_US.UTF-8";

  networking.networkmanager.enable = true;

  # Fish is the primary interactive shell for this workstation.
  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    papirus-icon-theme
    bibata-cursors
    git
    curl
    wget
    kitty
    vim
    btop
    ranger
    gh
    glab
  ];

  programs.vim = {
   enable = true;
   defaultEditor = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
     };
  };

  services.tailscale.enable = true;

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.fira-code
    (google-fonts.override { fonts = [ "Poppins" ]; })
  ];
  fonts.fontconfig.defaultFonts.monospace = [ "FiraCode Nerd Font Mono" ];
}
