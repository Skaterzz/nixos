{ config, lib, pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # The weather widget ported from the dotfiles was configured for Detroit;
  # adjust if this machine lives somewhere else.
  time.timeZone = "America/Detroit";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.networkmanager.enable = true;

  # Fish is the primary interactive shell for this workstation.
  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    kitty
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-emoji
    nerd-fonts.fira-code
  ];
  fonts.fontconfig.defaultFonts.monospace = [ "FiraCode Nerd Font Mono" ];
}
