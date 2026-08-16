{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  kernelPkgs = import inputs.nixpkgs-kernel {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };

  regreetSession = pkgs.writeShellScript "regreet-session" ''
    # Cage starts at the displays' preferred 60 Hz modes. Raise both before
    # ReGreet draws so the greeter and the desktop use the same layout.
    ${pkgs.wlr-randr}/bin/wlr-randr \
      --output DP-1 --on --mode 1920x1080@144.001Hz --pos 0,0 \
      --output DP-2 --on --mode 1920x1080@144.001Hz --pos 1920,0 \
      || true

    exec ${lib.getExe pkgs.regreet}
  '';
in
{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/niri.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/emoji.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/ddcci.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/development.nix
    ../../modules/nixos/virtualization.nix
    ../../modules/nixos/ai.nix
  ];

  networking.hostName = "nixos";

  # This machine is managed from this checkout, whose nixConfig supplies the
  # kernel cache. Trust it without requiring --accept-flake-config on every
  # rebuild; this also accepts nixConfig from any other flake built here.
  nix.settings.accept-flake-config = true;

  local = {
    desktop.primaryUser = "xray";
    backlight.ddcci.enable = true;
    boot = {
      loader = "systemd-boot";
      plymouth.enable = true;
    };
    sddm.theme = "stock";
    ai.enable = false;
    virtualisation.singleGpuPassthrough.enable = false;
  };

  # Preserve the kernel/NVIDIA pairing that reliably exposes both DisplayPort
  # EDIDs. Newer kernels can be tried once both panels survive a cold boot and
  # a complete DPMS cycle.
  boot = {
    kernelPackages = lib.mkForce kernelPkgs.linuxPackages_zen;
    blacklistedKernelModules = [ "nouveau" ];
    kernelParams = [
      "acpi_enforce_resources=lax"
      "nvidia_drm.fbdev=1"
      "amd_iommu=on"
      "iommu=pt"
    ];
    zswap = {
      enable = true;
      compressor = "lz4";
      maxPoolPercent = 20;
    };
  };
  hardware = {
    enableRedistributableFirmware = true;
    deviceTree.enable = lib.mkForce false;
    cpu.amd.updateMicrocode = true;
    nvidia.package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.stable;
    uinput.enable = true;
  };
  system.boot.loader.kernelFile = lib.mkForce "bzImage";

  # The existing mutable account owns its password in /etc/shadow. Omitting
  # password options here preserves that hash across activation.
  users.mutableUsers = true;
  users.users = {
    root.shell = pkgs.fish;
    xray = {
      isNormalUser = true;
      uid = 1000;
      description = "xray";
      shell = pkgs.fish;
      extraGroups = [
        "docker"
        "input"
        "libvirtd"
        "networkmanager"
        "uinput"
        "video"
        "wheel"
      ];
    };
  };

  # The upstream Niri module uses SDDM. This host uses greetd and ReGreet,
  # while leaving the other upstream hosts unchanged.
  services.displayManager.sddm.enable = lib.mkForce false;
  systemd.services.sddm-theme-sync.enable = lib.mkForce false;
  systemd.paths.sddm-theme-sync.enable = lib.mkForce false;
  services.greetd = {
    enable = true;
    settings.default_session.command = "${pkgs.dbus}/bin/dbus-run-session ${lib.getExe pkgs.cage} -s -d -m extend -- ${regreetSession}";
  };
  services.displayManager.regreet = {
    enable = true;
    cageArgs = [
      "-s"
      "-d"
      "-m"
      "extend"
    ];
    settings = {
      background = {
        path = inputs.dotfiles + "/dot_local/share/wallpapers/nixos.png";
        fit = "Cover";
      };
      appearance.greeting_msg = "Welcome back, xray";
      widget.clock = {
        format = "%A %d %B - %H:%M";
        resolution = "500ms";
      };
    };
    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
    font = {
      package = pkgs.google-fonts.override { fonts = [ "Poppins" ]; };
      name = "Poppins";
      size = 12;
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  time.timeZone = lib.mkForce "America/Toronto";
  i18n.defaultLocale = lib.mkForce "en_CA.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_CA.UTF-8";
    LC_IDENTIFICATION = "en_CA.UTF-8";
    LC_MEASUREMENT = "en_CA.UTF-8";
    LC_MONETARY = "en_CA.UTF-8";
    LC_NAME = "en_CA.UTF-8";
    LC_NUMERIC = "en_CA.UTF-8";
    LC_PAPER = "en_CA.UTF-8";
    LC_TELEPHONE = "en_CA.UTF-8";
    LC_TIME = lib.mkForce "en_CA.UTF-8";
  };

  system.stateVersion = "26.05";
}
