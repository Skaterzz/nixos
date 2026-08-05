{ config, lib, pkgs, ... }:


let 
  cfg = config.local.boot;
in
{
  # Power behaviour that every host wants: no idle suspend while on mains.
  # See modules/nixos/power.nix and local.power.noAutoSleepOnAC.
  imports = [ ./power.nix ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # NOTE: `allowed-users` is deliberately left at its default of "*".
  #
  # It was briefly set to [ "root" "@wheel" ], which broke the two accounts
  # that are non-wheel on purpose (amandak and sabom — see users.nix). It
  # gates who may open a connection to nix-daemon *at all*, so every one of
  # their nix clients was refused at the handshake: home-manager-<user>.service
  # failed on every switch with
  #
  #   error: cannot open connection to remote store 'daemon':
  #   error: read of 32768 bytes: Connection reset by peer
  #
  # which reads like a network fault and is actually an authorization refusal.
  # nix-shell and direnv would have gone the same way for those users.
  #
  # It is also not the setting that grants anything. `trusted-users` is — a
  # trusted user can name its own substituters and have their contents taken
  # on faith — and modules/nixos/development.nix pins that to root and @wheel,
  # which is the trust the admin account already has via sudo. Restricting
  # `allowed-users` on top of that keeps out no one who matters on a
  # single-admin laptop; it only locks out the humans who log into it.

  # NVIDIA, Steam, VS Code, Vivaldi, Spotify and Discord are all unfree.
  # This has to be set as a module option so it applies to the system pkgs
  # (and, via home-manager.useGlobalPkgs, to joshr's profile too).
  nixpkgs.config.allowUnfree = true;
  nix.gc = {
    automatic = true;
  
    # Weekly, Sunday morning in the machine's local timezone.
    dates = "Sun 04:00";
  
    # This is already the default, but explicit is clearer.
    persistent = true;
  
    # Avoid GC beginning immediately during boot when the scheduled run
    # was missed. Also prevents several machines starting simultaneously.
    randomizedDelaySec = "1h";
  
    # Preserve approximately two weeks of rollback history.
    options = "--delete-older-than 14d";
  };
  # Create a custom daily service that safely handles "+10"
# systemd.services.nix-clean-generations = {
#   description = "Clean all profiles down to the last ${toString cfg.maxGenerations} generations and run GC";
#   startAt = "daily";
#   serviceConfig = {
#     Type = "oneshot";
#     ExecStart = pkgs.writeShellScript "nix-clean" ''
#       # 1. Clear system profile generations down to maxGenerations
#       ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --delete-generations +${toString cfg.maxGenerations}
# 
#       # 2. Clear all per-user profiles down to maxGenerations
#       for profile in /nix/var/nix/profiles/per-user/*; do
#         if [ -d "$profile" ]; then
#           ${pkgs.nix}/bin/nix-env --profile "$profile/profile" --delete-generations +${toString cfg.maxGenerations}
#         fi
#       done
# 
#       # 3. Collect garbage to free up physical space
#       ${pkgs.nix}/bin/nix-store --gc
#     '';
#   };
# };

# If the pc was shut off past the clean time, make the timer run the service.
systemd.timers.nix-clean-generations.timerConfig.Persistent = true;

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
