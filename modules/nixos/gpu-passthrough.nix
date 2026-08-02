{ config, lib, pkgs, ... }:

# Single GPU passthrough: hand the machine's only graphics card to a guest for
# as long as that guest is running, and take it back when it stops.
#
# The ordinary kind of VFIO passthrough gives a *second* card to a VM. The host
# never wants it, so it is bound to vfio-pci in the initrd and that is the end
# of the story. This box has one card. The host is using it — the greeter, the
# compositor, the framebuffer console — so before a guest can have it, all of
# that has to let go, and afterwards all of it has to come back. Nothing in
# libvirt does that, hence this module.
#
# What it costs, stated plainly: **starting one of these guests logs you out.**
# The display manager is stopped, the session with it, and the screen goes dark
# until the guest's own output appears on the same monitor. Quitting the guest
# brings the greeter back, and you log in again. That is not a bug in the
# implementation, it is what "one GPU, two operating systems" means.
#
# How libvirt calls this
# ----------------------
# libvirtd runs every executable in /var/lib/libvirt/hooks/qemu.d/ around a
# domain's lifecycle, with argv `<domain> <operation> <sub-operation> <extra>`
# and the domain XML on stdin. NixOS installs them from
# `virtualisation.libvirtd.hooks.qemu`, which is the last line of this file.
#
# Two of those operations matter:
#
#   * `prepare/begin` — before libvirt has allocated anything for the guest.
#     The only point at which the host can still be told to drop the card
#     without a half-built domain in the way.
#
#   * `release/end` — after the domain is fully torn down and libvirt has
#     already reattached anything it detached itself. The card is genuinely
#     free by then, so the driver can be loaded back onto it.
#
# The hook is synchronous: libvirtd waits for it, and a non-zero exit refuses
# the domain start. That is the right behaviour *provided* the host has been
# put back first, which is what the failure path below does — a refused VM is
# recoverable, a machine with no display manager and no GPU driver is not.
#
# What the release side does, in order, and why
# ---------------------------------------------
#   1. Stops `display-manager.service` (and anything in `stopServices`). The
#      compositor is the largest single consumer of the card.
#   2. Unbinds the framebuffer console (`/sys/class/vtconsole/vtcon*`), which
#      holds the card without being a service at all.
#   3. Unbinds the boot framebuffer — efi-framebuffer on the old path,
#      simple-framebuffer on anything recent enough to be using simpledrm.
#   4. Unloads the host GPU driver, retrying while it is busy: `systemctl stop`
#      returns when the *unit* is gone, and a session's last processes can hold
#      a /dev/nvidia* open for a moment after that.
#   5. Loads vfio-pci and binds the guest's PCI functions to it through
#      `driver_override`, so the re-probe can only land on vfio-pci and the
#      host driver cannot race for the card it has just let go of.
#
# The release side records what it stopped and unbound in
# /run/single-gpu-passthrough.state, and the reclaim side replays exactly that
# and nothing else, in reverse. /run is tmpfs, so a reboot with a guest running
# leaves no stale file to act on — and the reclaim side copes with the file
# being absent anyway, because that is also the state you are in when you run
# it by hand to dig the machine out.
#
# What this module deliberately does not do
# -----------------------------------------
#   * **It does not touch the kernel command line.** The IOMMU has to be on for
#     any of this to work, and on this box that is `amd_iommu=on iommu=pt` in
#     hosts/gamestation/kernel-params.nix, where the rest of the hardware's
#     flags live. A missing flag is a warning at build time, not an error: a
#     recent kernel may well have the IOMMU on already because the firmware
#     does.
#   * **It does not bind anything at boot.** That is the whole difference from
#     multi-GPU passthrough — the card must belong to the host until a guest
#     asks for it.
#   * **It does not define a VM.** Make the guest in virt-manager as usual, add
#     the GPU's PCI functions to it, and name it in `vms` here.
#
# Trying it, and getting out of trouble
# -------------------------------------
#     journalctl -t single-gpu-passthrough -f    # what the hook did
#     journalctl -u libvirtd -f                  # what libvirt made of it
#
# The hook is on PATH as `single-gpu-passthrough` for driving by hand — most
# usefully from an SSH session or a TTY, after a guest has died in a way that
# never produced a release/end:
#
#     sudo single-gpu-passthrough <domain> release end < /dev/null
#
# Ctrl+Alt+F2 still gets a TTY throughout, right up until step 2 above; after
# that, SSH is the way in. `base.nix` has sshd on with password auth off.
let
  cfg = config.local.virtualisation.singleGpuPassthrough;

  # An IOMMU is the one prerequisite this module can check for and can't
  # provide. Warning rather than asserting because the flag is not the only way
  # to have one: an AMD box whose firmware enables it, on a kernel new enough to
  # take that at face value, needs nothing on the command line at all.
  iommuOnCmdline =
    lib.elem "amd_iommu=on" config.boot.kernelParams
    || lib.elem "intel_iommu=on" config.boot.kernelParams;

  hook = pkgs.writeShellApplication {
    name = "single-gpu-passthrough";

    runtimeInputs = with pkgs; [
      coreutils # sleep, timeout, printf, readlink, rm
      gnugrep
      kmod # modprobe, lsmod
      systemd # systemctl
      util-linux # logger
      xmlstarlet # reads the guest's <hostdev> entries off stdin
    ];

    text = ''
      # The ERR trap below has to survive being inside a function, which is
      # what errtrace does. Without it a failure part-way through release_gpu
      # would leave the machine with no display manager and no GPU driver.
      set -E

      guest="''${1:-}"
      op="''${2:-}"
      subop="''${3:-}"

      # What the release side stopped and unbound, so the reclaim side puts
      # back exactly that and nothing else. /run is tmpfs, so a reboot with a
      # guest running leaves no stale file to act on.
      stateFile=/run/single-gpu-passthrough.state

      displayManagerUnit="display-manager.service"
      vms=(${lib.escapeShellArgs cfg.vms})
      configuredDevices=(${lib.escapeShellArgs cfg.pciDevices})
      hostModules=(${lib.escapeShellArgs cfg.hostDriverModules})
      extraUnits=(${lib.escapeShellArgs cfg.stopServices})

      devices=()

      log() {
        # --stderr as well as the journal: libvirtd captures a hook's stderr
        # into its own log, which is where you'll be looking when a domain
        # refuses to start.
        logger --stderr --tag single-gpu-passthrough -- "$*" || true
      }

      remember() {
        printf '%s\n' "$*" >> "$stateFile"
      }

      # libvirt feeds the domain XML in on stdin for every domain operation.
      # Read it before deciding anything, so an early exit can't leave
      # libvirtd writing into a pipe that has already been closed.
      domainXml=""
      if [ ! -t 0 ]; then
        domainXml="$(timeout 5 cat || true)"
      fi

      # prepare/begin is before libvirt has allocated anything for the guest;
      # release/end is after it has torn the domain down again. The other
      # operations (start, started, stopped, migrate, restore, attach) are
      # either too late to free the card or too early to give it back.
      case "$op/$subop" in
        prepare/begin) action=release ;;
        release/end) action=reclaim ;;
        *) exit 0 ;;
      esac

      wanted=no
      for vm in "''${vms[@]}"; do
        if [ "$vm" = "$guest" ]; then
          wanted=yes
        fi
      done
      if [ "$wanted" != yes ]; then
        exit 0
      fi

      # Which PCI functions to hand over. The configured list wins; otherwise
      # take the guest's own <hostdev> entries, which is the same GPU written
      # down once instead of twice.
      collect_devices() {
        local raw dom bus slot fn addr

        devices=()

        if [ "''${#configuredDevices[@]}" -gt 0 ]; then
          devices=("''${configuredDevices[@]}")
          return 0
        fi

        if [ -z "$domainXml" ]; then
          return 0
        fi

        while read -r raw; do
          if [ -z "$raw" ]; then
            continue
          fi
          IFS=':.' read -r dom bus slot fn <<< "$raw"
          # libvirt writes these as 0x-prefixed hex of varying width and the
          # kernel wants 0000:0b:00.0. An empty field arithmetics to 0, which
          # is the right reading of a domain that omits @domain.
          printf -v addr '%04x:%02x:%02x.%x' \
            "$((dom))" "$((bus))" "$((slot))" "$((fn))"
          devices+=("$addr")
        done < <(
          printf '%s' "$domainXml" \
            | xmlstarlet sel -T -t \
              -m "//devices/hostdev[@type='pci']/source/address" \
              -v "concat(@domain,':',@bus,':',@slot,'.',@function)" -n \
            || true
        )
      }

      bind_to_vfio() {
        local dev="$1"
        local path="/sys/bus/pci/devices/$dev"
        local current=""

        if [ ! -d "$path" ]; then
          log "no PCI device at $dev — skipping it"
          return 0
        fi

        if [ -L "$path/driver" ]; then
          current="$(readlink -f "$path/driver")"
          current="''${current##*/}"
        fi

        if [ "$current" = "vfio-pci" ]; then
          log "$dev is already on vfio-pci"
          return 0
        fi

        log "binding $dev to vfio-pci (was ''${current:-unbound})"
        # The override goes on first, so the re-probe below can only land on
        # vfio-pci and the host driver cannot race us for the card it has
        # just been made to let go of.
        echo "vfio-pci" > "$path/driver_override"
        if [ -n "$current" ]; then
          echo "$dev" > "$path/driver/unbind"
        fi
        echo "$dev" > /sys/bus/pci/drivers_probe
      }

      unbind_from_vfio() {
        local dev="$1"
        local path="/sys/bus/pci/devices/$dev"
        local current=""

        if [ ! -d "$path" ]; then
          return 0
        fi

        if [ -L "$path/driver" ]; then
          current="$(readlink -f "$path/driver")"
          current="''${current##*/}"
        fi

        if [ -w "$path/driver_override" ]; then
          # A blank override is what lets the kernel pick the real driver.
          if ! printf '\n' > "$path/driver_override"; then
            log "could not clear the driver override on $dev — continuing"
          fi
        fi

        if [ "$current" = "vfio-pci" ]; then
          log "unbinding $dev from vfio-pci"
          if ! echo "$dev" > "$path/driver/unbind"; then
            log "could not unbind $dev — continuing"
          fi
        fi

        if ! echo "$dev" > /sys/bus/pci/drivers_probe; then
          log "nothing would bind to $dev — continuing"
        fi
      }

      unload_host_modules() {
        local m
        for m in "''${hostModules[@]}"; do
          m="''${m//-/_}"
          if lsmod | grep -q "^$m "; then
            if ! modprobe -r -- "$m"; then
              return 1
            fi
          fi
        done
        return 0
      }

      release_gpu() {
        local unit vtcon drv dev name attempt freed

        log "domain $guest is starting — taking the GPU off the host"
        : > "$stateFile"

        for unit in "$displayManagerUnit" "''${extraUnits[@]}"; do
          if systemctl is-active --quiet "$unit"; then
            log "stopping $unit"
            systemctl stop "$unit"
            remember "unit $unit"
          fi
        done

        # The framebuffer console holds the card too, and is not a service.
        for vtcon in /sys/class/vtconsole/vtcon*; do
          if [ ! -w "$vtcon/bind" ]; then
            continue
          fi
          if grep -q "frame buffer device" "$vtcon/name" 2>/dev/null; then
            log "unbinding the framebuffer console on ''${vtcon##*/}"
            if echo 0 > "$vtcon/bind"; then
              remember "vtcon $vtcon"
            else
              log "could not unbind ''${vtcon##*/} — continuing"
            fi
          fi
        done

        # Whatever drew the boot splash. Which of these exists depends on the
        # firmware and the kernel: efi-framebuffer on the old path,
        # simple-framebuffer on anything recent enough to use simpledrm.
        for drv in efi-framebuffer simple-framebuffer vesa-framebuffer; do
          if [ ! -d "/sys/bus/platform/drivers/$drv" ]; then
            continue
          fi
          for dev in /sys/bus/platform/drivers/"$drv"/*; do
            name="''${dev##*/}"
            case "$name" in
              bind | unbind | uevent | module | new_id | remove_id) continue ;;
            esac
            if [ ! -L "$dev" ]; then
              continue
            fi
            log "unbinding $name from $drv"
            if echo "$name" > "/sys/bus/platform/drivers/$drv/unbind"; then
              remember "fb $drv $name"
            else
              log "could not unbind $name from $drv — continuing"
            fi
          done
        done

        # The retries are for the session: systemctl stop returns when the
        # unit is gone, but a compositor's last processes can hold a
        # /dev/nvidia* open for a moment after that, and the module will not
        # come out while they do.
        freed=no
        for attempt in 1 2 3 4 5; do
          if unload_host_modules; then
            freed=yes
            break
          fi
          log "the GPU driver is still busy (attempt $attempt) — waiting"
          sleep 2
        done
        if [ "$freed" != yes ]; then
          fail "could not unload the host GPU driver (''${hostModules[*]})"
        fi

        log "loading vfio-pci"
        modprobe vfio-pci

        for dev in "''${devices[@]}"; do
          bind_to_vfio "$dev"
        done

        if [ "''${#devices[@]}" -eq 0 ]; then
          # Not a problem in itself: a <hostdev managed='yes'> guest — which
          # is what virt-manager writes — has libvirt do the binding, and it
          # can now that the host driver is out of the way.
          log "no PCI devices named or found in the domain XML;" \
            "leaving the bind to libvirt"
        fi
      }

      reclaim_gpu() {
        local dev m i kind a b vtcon

        log "domain $guest has stopped — giving the GPU back to the host"

        for dev in "''${devices[@]}"; do
          unbind_from_vfio "$dev"
        done

        for m in vfio_pci vfio_iommu_type1 vfio; do
          if lsmod | grep -q "^$m "; then
            if ! modprobe -r -- "$m"; then
              log "$m would not unload — continuing"
            fi
          fi
        done

        # Back in, in the reverse of the order they came out.
        for (( i = ''${#hostModules[@]} - 1; i >= 0; i-- )); do
          if ! modprobe -- "''${hostModules[i]}"; then
            log "''${hostModules[i]} would not load — continuing"
          fi
        done

        if [ -r "$stateFile" ]; then
          # Consoles first and the display manager last: the greeter wants a
          # card that is already back.
          while read -r kind a b; do
            case "$kind" in
              fb)
                log "rebinding $b to $a"
                if ! echo "$b" > "/sys/bus/platform/drivers/$a/bind"; then
                  log "could not rebind $b — continuing"
                fi
                ;;
              vtcon)
                log "rebinding the framebuffer console on ''${a##*/}"
                if ! echo 1 > "$a/bind"; then
                  log "could not rebind ''${a##*/} — continuing"
                fi
                ;;
            esac
          done < "$stateFile"

          while read -r kind a b; do
            case "$kind" in
              unit)
                log "starting $a"
                if ! systemctl start "$a"; then
                  log "$a would not start — continuing"
                fi
                ;;
            esac
          done < "$stateFile"

          rm -f "$stateFile"
        else
          # No record of the release half — a reboot with the guest running,
          # or this script run by hand to dig the machine out. Restore the
          # things whose absence leaves no way back in.
          log "no record of what was stopped;" \
            "restoring the console and $displayManagerUnit"
          for vtcon in /sys/class/vtconsole/vtcon*; do
            if [ -w "$vtcon/bind" ]; then
              if ! echo 1 > "$vtcon/bind"; then
                log "could not rebind ''${vtcon##*/} — continuing"
              fi
            fi
          done
          if ! systemctl start "$displayManagerUnit"; then
            log "$displayManagerUnit would not start — continuing"
          fi
        fi
      }

      # Failing out of the release half without putting the host back means a
      # black screen and no guest either. So: undo, then report the failure.
      # libvirt turns a non-zero hook into a refused domain start, which is
      # the right outcome once the desktop is back.
      fail() {
        log "$*"
        log "restoring the host"
        reclaim_gpu
        exit 1
      }

      on_error() {
        trap - ERR
        fail "the host-side preparation failed"
      }

      collect_devices

      case "$action" in
        release)
          trap on_error ERR
          release_gpu
          trap - ERR
          log "the GPU is free; handing $guest over to libvirt"
          ;;
        reclaim)
          reclaim_gpu
          log "the host has the GPU back"
          ;;
      esac
    '';
  };
in
{
  # local.* lives in its own module so this one can stay a config attrset.
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.libvirtd.enable;
        message = ''
          local.virtualisation.singleGpuPassthrough.enable needs libvirtd to
          have something to hook. Import modules/nixos/virtualization.nix on
          this host, or turn the option off.
        '';
      }
    ];

    warnings =
      lib.optional (cfg.vms == [ ]) ''
        local.virtualisation.singleGpuPassthrough is on but its `vms` list is
        empty, so the hook will never fire on any guest. Name the libvirt
        domains that should get the GPU — the names `virsh list --all` prints.
      ''
      ++ lib.optional (!iommuOnCmdline) ''
        local.virtualisation.singleGpuPassthrough is on but boot.kernelParams
        has neither amd_iommu=on nor intel_iommu=on. VFIO needs an IOMMU; if
        the firmware and kernel haven't turned one on by themselves, the guest
        will fail to start with "No IOMMU group". See
        hosts/gamestation/kernel-params.nix for where those flags live here.
      '';

    # Installed to /var/lib/libvirt/hooks/qemu.d/single-gpu-passthrough by the
    # libvirtd module's preStart, which is also why a changed hook needs
    # `systemctl restart libvirtd` (or a reboot) rather than only a rebuild.
    virtualisation.libvirtd.hooks.qemu.single-gpu-passthrough = lib.getExe hook;

    # For running the reclaim half by hand when a guest has gone away without
    # libvirt noticing. See the header.
    environment.systemPackages = [ hook ];
  };
}
