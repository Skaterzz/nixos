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

  pixieTheme = inputs.pixie-sddm.packages.${pkgs.stdenv.hostPlatform.system}.pixie-sddm;
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
    ../../modules/nixos/kernel.nix
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
    kernel.cachyos.enable = false;
    virtualisation.singleGpuPassthrough.enable = false;
  };

  boot = {
    # Newer kernels leave the AOC connector present but expose no EDID or
    # modes. Keep the kernel/NVIDIA pairing that survives cold boot and DPMS.
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

  # Pixie runs on the Qt 6 SDDM supplied by the shared niri module. Keep the
  # theme in both SDDM's QML environment and the system theme search path.
  services.displayManager.sddm = {
    theme = "pixie";
    extraPackages = [
      pixieTheme
      pkgs.kdePackages.qt5compat
      pkgs.kdePackages.qtdeclarative
      pkgs.kdePackages.qtsvg
    ];
  };
  environment.systemPackages = [ pixieTheme ];

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
