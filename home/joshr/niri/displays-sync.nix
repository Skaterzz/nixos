{ config, lib, pkgs, ... }:

# `niri-sync-displays` — copy niri's live output layout into a
# kwinoutputconfig.json for the SDDM greeter.
#
# Why this isn't generated from scratch
# -------------------------------------
# The greeter runs its own kwin_wayland, which reads kwinoutputconfig.json.
# KWin matches saved entries to physical monitors by EDID identifier and hash
# first, falling back to connector name (see findOutputIndex in
# outputconfigurationstore.cpp). A file written from nothing has no EDID
# fields, so KWin would fail to match it and silently auto-detect instead.
#
# So this *edits* the file KWin already wrote for joshr: it keeps every
# entry's identity and untouched settings, and overwrites only the mode,
# scale and position from `niri msg outputs`.
#
# Output goes to the niri state dir rather than straight to the greeter,
# because /var/lib/sddm is root-owned. The sddm-theme-sync path unit in
# modules/nixos/niri.nix watches that file and does the privileged copy, so
# this needs no sudo.
let
  stateDir = "${config.home.homeDirectory}/.local/state/niri-theme";

  syncDisplays = pkgs.writers.writePython3Bin "niri-sync-displays"
    { flakeIgnore = [ "E501" ]; }
    ''
      """Translate niri's current output layout into a KWin output config."""
      import glob
      import json
      import os
      import subprocess
      import sys

      STATE = "${stateDir}"
      TEMPLATE = os.path.expanduser("~/.config/kwinoutputconfig.json")
      OUT = os.path.join(STATE, "kwinoutputconfig.json")


      def die(msg):
          print("niri-sync-displays: " + msg, file=sys.stderr)
          sys.exit(1)


      def find_socket():
          """Locate niri's IPC socket.

          NIRI_SOCKET is set inside the session, but this also runs from
          home-manager activation, which is a systemd service with none of
          the session environment. Fall back to globbing the runtime dir.
          """
          sock = os.environ.get("NIRI_SOCKET")
          if sock and os.path.exists(sock):
              return sock
          runtime = os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid()
          found = sorted(glob.glob(os.path.join(runtime, "niri.*.sock")))
          return found[0] if found else None


      sock = find_socket()
      if sock is None:
          die("niri is not running (no IPC socket found)")

      env = dict(os.environ, NIRI_SOCKET=sock)

      # niri returns a dict keyed by connector name.
      try:
          raw = subprocess.check_output(
              ["${pkgs.niri}/bin/niri", "msg", "--json", "outputs"],
              text=True,
              env=env,
          )
      except (subprocess.CalledProcessError, FileNotFoundError):
          die("could not talk to niri via " + sock)
      niri = json.loads(raw)

      # Prefer a previously generated file so repeated runs stay idempotent,
      # otherwise start from whatever KWin last wrote.
      template = OUT if os.path.exists(OUT) else TEMPLATE
      if not os.path.exists(template):
          die(
              "no kwinoutputconfig.json to work from at " + TEMPLATE + ".\n"
              "  KWin writes it, so boot the Plasma host once and arrange the\n"
              "  displays there; this script then keeps it in step with niri."
          )

      with open(template) as fh:
          doc = json.load(fh)

      # Top level is an array of sections: one named "outputs" (per-monitor
      # settings) and one named "setups" (arrangements, which carry position).
      if not isinstance(doc, list):
          die("unexpected format in " + template + " - expected a JSON array")

      outputs = next((s for s in doc if s.get("name") == "outputs"), None)
      setups = next((s for s in doc if s.get("name") == "setups"), None)
      if outputs is None:
          die("no 'outputs' section in " + template)

      index_of = {}
      for i, entry in enumerate(outputs.get("data", [])):
          name = entry.get("connectorName")
          if name:
              index_of[name] = i

      touched = []
      skipped = []

      for name, out in niri.items():
          if name not in index_of:
              skipped.append(name)
              continue

          modes = out.get("modes") or []
          current = out.get("current_mode")
          entry = outputs["data"][index_of[name]]

          if current is not None and 0 <= current < len(modes):
              mode = modes[current]
              # KWin's refreshRate is millihertz, and so is niri's - no
              # conversion. "basic" and "cvt" are alternatives; drop any cvt
              # so the two can't disagree.
              entry.setdefault("mode", {})
              entry["mode"].pop("cvt", None)
              entry["mode"].setdefault("flags", 0)
              entry["mode"]["basic"] = {
                  "width": mode["width"],
                  "height": mode["height"],
                  "refreshRate": mode["refresh_rate"],
              }

          logical = out.get("logical")
          if logical:
              entry["scale"] = logical["scale"]

          touched.append(name)

      # Positions live in the setups section, keyed by index into outputs.
      if setups:
          name_of = {i: n for n, i in index_of.items()}
          for setup in setups.get("data", []):
              for so in setup.get("outputs", []):
                  name = name_of.get(so.get("outputIndex"))
                  if name is None or name not in niri:
                      continue
                  logical = niri[name].get("logical")
                  if logical:
                      so["position"] = {"x": logical["x"], "y": logical["y"]}
                      so["enabled"] = True

      os.makedirs(STATE, exist_ok=True)
      tmp = OUT + ".tmp"
      with open(tmp, "w") as fh:
          json.dump(doc, fh, indent=4)
          fh.write("\n")
      os.replace(tmp, OUT)

      print("wrote " + OUT)
      for name in touched:
          print("  synced  " + name)
      for name in skipped:
          print("  skipped " + name + " (no entry in the KWin config)")
      if skipped:
          print(
              "\nSkipped outputs have no EDID-identified entry to update.\n"
              "Arrange them once in a Plasma session so KWin records them."
          )
      print("\nApplies at the next greeter start - log out or reboot to see it.")
    '';
in
{
  home.packages = [ syncDisplays ];

  # Short alias for running it by hand.
  programs.fish.shellAliases.sync-displays = "niri-sync-displays";
  programs.bash.shellAliases.sync-displays = "niri-sync-displays";
  programs.zsh.shellAliases.sync-displays = "niri-sync-displays";

  # Also run on every home-manager activation, i.e. every nixos-rebuild
  # switch — display changes usually arrive that way.
  #
  # `|| true` because this legitimately can't work in several ordinary cases:
  # rebuilding over SSH or from a TTY with no niri running, rebuilding the
  # Plasma host, or a first build before any KWin config exists. None of
  # those should fail the rebuild, so the script's diagnostics go to the
  # activation log and the rebuild carries on.
  home.activation.syncNiriDisplays = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${lib.getExe syncDisplays} || true
  '';
}
