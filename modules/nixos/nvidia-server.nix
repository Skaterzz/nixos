{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# The NVIDIA driver on a machine with no monitor attached, with the encoder
# unlocked.
#
# modules/nixos/nvidia.nix is the desktop version of this file, and the two
# are about different things: that one is a card driving displays and coming
# back from suspend, this one is a card doing work while nobody is logged in
# — transcoding, CUDA, a model server, a container that asked for a GPU.
# **Import one or the other, never both.** They would both write
# `hardware.nvidia.package` and the rebuild would stop with a conflict.
#
# The options are `local.nvidia.*` in modules/nixos/options.nix. Only this
# module reads them; nvidia.nix pins its own driver and ignores them.
#
# services.xserver.videoDrivers on a headless box
# -----------------------------------------------
# It is set below, and it has to be. nixpkgs gates its *entire* NVIDIA module
# — the kernel modules, the udev rules, the libraries in
# /run/opengl-driver, nvidia-smi, persistenced — on "nvidia" appearing in
# that list. Leave it out and every `hardware.nvidia.*` setting here is
# silently inert: the machine boots, and nothing has a driver.
#
# It does not enable X. `services.xserver.enable` is what does that, it stays
# false, and nothing here pulls in a display manager or a session.
#
# The patch
# ---------
# GeForce cards ship with two limits that are policy rather than silicon:
#
#   * NVENC refuses more than a handful of simultaneous encode sessions —
#     three on older drivers, five on newer ones. The fourth (or sixth)
#     `ffmpeg -c:v h264_nvenc` fails with "OpenEncodeSessionEx failed: out of
#     memory (10)" while the card sits at 20% utilisation. This is the limit
#     that decides how many streams a transcoding server can actually serve.
#
#   * NvFBC — whole-framebuffer capture, the cheapest way to grab a screen —
#     is refused unless the card is a Quadro. Sunshine, OBS and the remote
#     desktops fall back to slower paths without it.
#
# Both live in userspace libraries as a branch on the card's model, and
# <https://github.com/keylase/nvidia-patch> is the long-standing project that
# publishes, per driver version, the byte sequence to overwrite so the branch
# is not taken. `inputs.nvidia-patch` is
# <https://github.com/icewind1991/nvidia-patch-nixos>, which wraps those
# offsets as a nixpkgs overlay: `pkgs.nvidia-patch.patch-nvenc` and
# `pkgs.nvidia-patch.patch-fbc` each take a driver package and return one
# whose `preFixup` seds the relevant `.so`, and `pkgs.nvidia-patch-list` is
# the version -> expression table they read.
#
# Three things follow from that mechanism and are worth knowing before
# turning it on:
#
#   * **It edits a binary NVIDIA ships**, which is a licence question you are
#     answering for yourself. Nothing here is redistributed — the sed runs on
#     this machine, on the driver this machine downloaded.
#
#   * **It is keyed on the exact driver version.** nixpkgs gets a new driver
#     before the offsets for it are published, so a channel that moves can
#     land on a version the table has never heard of. That is why
#     `local.nvidia.driver` defaults to "production" rather than "latest",
#     and why an unpatchable version warns loudly below instead of quietly
#     installing a capped driver. `local.nvidia.patch.required = true` turns
#     the warning into a failed rebuild for a host where the cap would be an
#     outage.
#
#     What the table currently knows, without leaving this repo:
#
#         nix eval .#nixosConfigurations.server-nvidia.pkgs.nvidia-patch-list.nvenc \
#           --apply builtins.attrNames
#
#     If a version is missing, `nix flake update nvidia-patch` is the first
#     thing to try — the offsets are added upstream within days of a release.
#
#   * **It changes the driver derivation**, so the first rebuild after
#     enabling it builds the driver here rather than fetching it from
#     cache.nixos.org — kernel module included, several minutes on a server
#     CPU. Same again on every kernel or driver bump. Nothing is compiled
#     twice for the same version.
#
# Checking it worked
# ------------------
# There is no flag to read; the check is to exceed the old limit.
#
#     nix shell nixpkgs#ffmpeg
#     for i in $(seq 1 8); do
#       ffmpeg -f lavfi -i testsrc=size=1920x1080:rate=30 -t 60 \
#              -c:v h264_nvenc -f null - &
#     done
#     nvidia-smi          # eight encoders, or a pile of session errors
#
# `nvidia-smi -q -d ENCODER_STATS` counts the sessions the card thinks it is
# running.
let
  cfg = config.local.nvidia;

  basePackage =
    if cfg.package != null then
      cfg.package
    else
      config.boot.kernelPackages.nvidiaPackages.${cfg.driver};

  # `pkgs.nvidia-patch-list.<kind>` is version -> sed expression. Asking it
  # first is what makes an unsupported driver a warning rather than an
  # "attribute 'x.y.z' missing" halfway through evaluating the host.
  patchable = kind: builtins.hasAttr basePackage.version pkgs.nvidia-patch-list.${kind};

  wanted = {
    fbc = cfg.patch.fbc;
    nvenc = cfg.patch.nvenc;
  };

  # fbc first, then nvenc, matching the order upstream's own example composes
  # them in. They touch different libraries, so the order is cosmetic.
  applied = lib.filter (kind: wanted.${kind} && patchable kind) [
    "fbc"
    "nvenc"
  ];

  missing = lib.filter (kind: wanted.${kind} && !patchable kind) [
    "fbc"
    "nvenc"
  ];

  driverPackage = lib.pipe basePackage (map (kind: pkgs.nvidia-patch."patch-${kind}") applied);

  missingMessage = ''
    nvidia-patch has no ${lib.concatStringsSep " or " missing} offsets for NVIDIA driver ${basePackage.version}.

    The driver installs unpatched, which means the NVENC session cap and the
    NvFBC restriction are both back. Ways out, cheapest first:

      * `nix flake update nvidia-patch` — the table is usually only days
        behind a driver release.
      * `local.nvidia.driver = "production"` in hosts/<host>/configuration.nix,
        the branch the table is most certain to know.
      * `local.nvidia.patch.${lib.head missing} = false` if this host doesn't
        need that half.

    What the table does cover:

      nix eval .#nixosConfigurations.<host>.pkgs.nvidia-patch-list.nvenc --apply builtins.attrNames
  '';
in
{
  # local.* lives in its own module so this one can stay a config attrset.
  imports = [ ./options.nix ];

  # Scoped to the hosts that import this file, because that is what a
  # `nixpkgs.overlays` inside a module means — it applies to the pkgs of this
  # host's configuration and nowhere else. The overlay adds three attributes
  # (`nvidia-patch`, `nvidia-patch-list`, `nvidia-patch-extractor`) and
  # rebuilds nothing on its own.
  nixpkgs.overlays = [ inputs.nvidia-patch.overlays.default ];

  # Not X. See the header — this list is how nixpkgs decides whether the
  # NVIDIA driver exists at all.
  services.xserver.videoDrivers = [ "nvidia" ];

  # Puts the driver's libraries where anything looking for a GPU expects
  # them (/run/opengl-driver/lib): libnvidia-encode for NVENC, libnvcuvid for
  # decode, libcuda for everything else.
  #
  # `enable32Bit` is deliberately left off. It exists for 32-bit games under
  # Proton and there is no Steam on this machine; on a desktop it is
  # modules/nixos/nvidia.nix's business.
  hardware.graphics.enable = true;

  hardware.nvidia = {
    package = driverPackage;

    inherit (cfg) open;

    # Needed for the DRM KMS path, which is what anything doing zero-copy
    # capture or rendering into a headless surface ends up on. Cheap, and its
    # absence is a confusing class of failure.
    modesetting.enable = true;

    # Keeps the driver initialised with no client attached. Without it the
    # card is torn down and re-initialised around every single job — a couple
    # of seconds of latency on each, clocks dropping back to idle in between,
    # and on some cards the persistence-mode-only ECC and clock settings
    # reverting. This is the one setting a headless card wants that a desktop
    # one doesn't care about.
    nvidiaPersistenced = cfg.persistenced;

    # A GUI control panel, on a machine with no GUI.
    nvidiaSettings = false;

    # The suspend/resume video-memory dance in modules/nixos/nvidia.nix is
    # for a machine that sleeps. This one doesn't — and the mechanism copies
    # the whole of VRAM to /tmp on the way down, which is the last thing a
    # box mid-transcode should do if something ever did call `systemctl
    # suspend`.
    powerManagement.enable = false;
    powerManagement.finegrained = false;
  };

  # The card, inside containers. Follows Docker rather than being on
  # unconditionally: the toolkit's whole job is injecting this driver into
  # containers, and there is nothing to inject into on a host that doesn't
  # run any.
  #
  # What it generates is a CDI spec — /var/run/cdi, regenerated by a udev
  # rule when the device appears — which is the current way to hand a GPU to
  # a container and the one this sets up:
  #
  #     docker run --rm --device=nvidia.com/gpu=all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi
  #
  # `--gpus all` is the older path. It goes through nvidia-container-runtime,
  # a wrapper nixpkgs only installs for the deprecated
  # `virtualisation.docker.enableNvidia`, which warns on every rebuild and
  # points back here. Use the device flag.
  #
  # The spec is generated against `hardware.nvidia.package` — the patched one
  # — so the libraries bind-mounted into the container are the patched
  # libraries. A stock jellyfin or ffmpeg image gets the unlocked encoder
  # without knowing anything about it.
  hardware.nvidia-container-toolkit.enable = cfg.containerToolkit;

  # Docker has understood CDI since 25.0. The flag is stated rather than
  # assumed because the failure it prevents — `--device=nvidia.com/gpu=all`
  # rejected as an unknown device — reads like a broken toolkit rather than a
  # daemon that wasn't asked. Unknown feature keys are ignored, so this is
  # safe on any version. Inert unless Docker is actually enabled.
  virtualisation.docker.daemon.settings = lib.mkIf cfg.containerToolkit {
    features.cdi = true;
  };

  environment.systemPackages = with pkgs; [
    # `nvidia-smi` arrives with the driver; this is the one worth adding —
    # per-process GPU/VRAM/encoder use, which is what "why are we only doing
    # four streams" is actually asking.
    nvtopPackages.nvidia
  ];

  warnings = lib.optional (missing != [ ] && !cfg.patch.required) missingMessage;

  assertions = [
    {
      assertion = cfg.patch.required -> missing == [ ];
      message = missingMessage;
    }
  ];
}
