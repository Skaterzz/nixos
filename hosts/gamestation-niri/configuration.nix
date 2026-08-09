{ config, lib, pkgs, ... }:

# The same physical machine as `gamestation`, running niri instead of Plasma.
#
#   sudo nixos-rebuild switch --flake .#gamestation-niri   # try niri
#   sudo nixos-rebuild switch --flake .#gamestation        # go back to Plasma
#
# Nothing is destroyed by switching either way, and the previous generation is
# always in the boot menu.
#
# It's a separate host rather than a toggle inside `gamestation` because the
# two configure *different display managers* — Plasma uses
# plasma-login-manager and niri uses SDDM — and NixOS won't let both be
# enabled at once.
{
  imports = [
    # Same machine, so the same hardware scan and the same kernel command
    # line — both live under ../gamestation/ and are shared by the two hosts.
    ../gamestation/hardware-configuration.nix
    ../gamestation/kernel-params.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix

    # niri replaces plasmalogin.nix: it brings its own session, SDDM, portals,
    # audio and polkit agent.
    ../../modules/nixos/niri.nix
    ../../modules/nixos/desktop.nix

    # Fluent Emoji as the system emoji font. The picker that shows it off is
    # Mod+. — see home/joshr/niri/emoji.nix.
    ../../modules/nixos/emoji.nix

    ../../modules/nixos/nvidia.nix

    # Brightness keys for the two DisplayPort monitors. Nothing on this
    # machine has an internal panel, so /sys/class/backlight is empty and
    # brightnessctl has nothing to write — see modules/nixos/ddcci.nix.
    ../../modules/nixos/ddcci.nix

    ../../modules/nixos/gaming.nix
    ../../modules/nixos/users.nix
    ../../modules/nixos/default-apps.nix

    # Development tooling: direnv, Docker, and the nix settings per-project
    # dev shells need.
    #
    # This is where Docker lives — the old virtualisation.nix was folded into
    # it — so dropping this import means no containers on this host either.
    ../../modules/nixos/development.nix

    # QEMU/KVM guests and the virt-manager GUI. Split out of development.nix,
    # so containers and VMs are separate switches.
    ../../modules/nixos/virtualization.nix

    # Local models: ollama on the card, a chat window for it, and the OpenClaw
    # agent. Its `local.ai` section is below; see modules/nixos/ai.nix and
    # "Local AI" in MANUAL.md.
    #
    # This is the only host that imports it. The laptop has no discrete GPU
    # and `server` has neither a GPU nor anyone sitting at it — a CPU-only
    # ollama would run there, slowly, if that is ever wanted. `server-nvidia`
    # is the one that could take this as-is, and deliberately doesn't; its
    # configuration.nix says why.
    ../../modules/nixos/ai.nix

    # NOT imported: ../../modules/nixos/plasma-xdg-data-dirs.nix
    #
    # That workaround exists because plasma-workspace's Qt wrapper builds an
    # ~18 KB XDG_DATA_DIRS. There is no plasma-workspace in a niri session, so
    # the bug it works around cannot occur here — and neither can the
    # from-source rebuild of plasma-workspace that the workaround costs.
  ];

  networking.hostName = "dialga";

  # DDC/CI brightness for the external monitors. Both displays get a
  # /sys/class/backlight/ddcci* device, which is what the XF86MonBrightness
  # keys and the swayidle dim have always been driving — they just had
  # nothing to drive here until now.
  local.backlight.ddcci.enable = true;

  # Single GPU passthrough. There is one card in this box, so lending it to a
  # guest means taking it off the host first: starting one of the domains
  # named below stops the display manager and with it this session, and
  # shutting the guest down brings the greeter back. See
  # modules/nixos/gpu-passthrough.nix for what happens in between, and
  # "Single GPU passthrough" in MANUAL.md for the setting-up.
  #
  # The IOMMU half of the prerequisite is already here — `amd_iommu=on
  # iommu=pt` in ../gamestation/kernel-params.nix, which both desk hosts
  # import.
  #
  # `vms` is empty until you name a domain, and a rebuild warns that the hook
  # can therefore never fire. Fill it in with what `virsh list --all` prints
  # for the guest that gets the card, e.g. `vms = [ "win11" ];`.
  local.virtualisation.singleGpuPassthrough = {
    enable = true;
    vms = [ ];
  };

  # Local AI. Three things on loopback, all on this machine's own card:
  # ollama serving models on 11434, Open WebUI as a chat window on 8080, and
  # the OpenClaw agent's control UI on 18789. Nothing here opens a firewall
  # port, and nothing here talks to a hosted model.
  #
  # `stopServices` above doesn't need ollama written into it — ai.nix adds its
  # own units to that list, so a guest can still take the card.
  #
  # **The first rebuild after this is a long one.** The card is NVIDIA, so
  # `acceleration` resolves to CUDA, and cache.nixos.org has no ollama-cuda to
  # hand out — it compiles here. `local.ai.ollama.acceleration = "cpu";` skips
  # that if you'd rather see the rest working first.
  local.ai = {
    enable = false;

    # Downloaded in the background after the server comes up, not built — a
    # rebuild doesn't wait on them. qwen3 is here rather than a better-known
    # name because the agent below needs tool calling and a context window of
    # at least 16K, and a model without those looks broken rather than small.
    # nomic-embed-text is what Open WebUI uses to index documents you give it.
    #
    # `ollama pull <model>` tries one without editing this; add it here once
    # it has earned its disk space. `ollama list` says what is actually down.
    ollama.models = [
      "qwen3"
      "qwen2.5-coder:14b"
      "deepseek-coder-v2"
      "deepseek-r1:14b"
      "deepseek-r1:8b"
      #"qwen3-coder"
      #"qwen3-coder-next"
      "nomic-embed-text"
    ];

    # The agent, running as joshr — see local.ai.openclaw.enable in
    # modules/nixos/options.nix for what that means and why it isn't on
    # everywhere. Points at the local qwen3 above, so it works out of the box
    # with no API key and nothing leaving the machine; `openclaw onboard`
    # swaps in a hosted provider later if that turns out to be wanted.
    openclaw = {
      enable = true;
      model = "ollama/qwen3";

      # Gone when nobody is logged in. Turn this on for an assistant that can
      # be messaged while the desk is empty — and see the option's note about
      # what an unattended agent means before doing so.
      linger = true;
    };
  };

  # Themed login screen: one sddm-astronaut build per palette, following the
  # desktop's theme and wallpaper.
  #
  # This was black on the primary display for a while. The cause looks to have
  # been the theme pointing Background at a wallpaper file that doesn't exist
  # until the switcher has run, and feeding that to a blur shader — see "The
  # login screen" in MANUAL.md. If it comes back black, set this to "stock"
  # and rebuild; a TTY (Ctrl+Alt+F2) still works, as does the previous
  # generation in the boot menu.
  local.sddm.theme = "astronaut";

  # Bootloader, its theming and other-OS detection: modules/nixos/boot.nix.
  # Defaults to limine; `local.boot.loader = "systemd-boot";` is the way back
  # to what this host used before that module existed.

  # The boot splash — the animated NixOS logo — over everything between the
  # boot menu and the login screen. See modules/nixos/plymouth.nix, and
  # `local.boot.plymouth.quiet` there for keeping the kernel messages.
  local.boot.plymouth.enable = true;

  # Do not bump this after the initial install; see the NixOS manual.
  system.stateVersion = "26.05";
}
