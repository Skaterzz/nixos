{ config, lib, pkgs, ... }:

# Local AI: models that run on this machine's own GPU, a chat window for them,
# and an agent that can act on them.
#
# Three programs, three jobs, all on loopback:
#
#   * **ollama** (`local.ai.ollama`) — the model runner. A system service that
#     holds the weights and answers HTTP on 127.0.0.1:11434. This is the part
#     that actually needs the graphics card.
#
#   * **Open WebUI** (`local.ai.webui`) — a browser chat window at
#     http://127.0.0.1:8080, pointed at ollama. The first visit asks you to
#     create an account; it is local to this machine and lives in a SQLite
#     file under /var/lib/open-webui, with nothing signed up to anywhere.
#
#   * **OpenClaw** (`local.ai.openclaw`) — the agent. Not a chat window: a
#     gateway process that holds sessions, tools and channels, with a control
#     UI at http://127.0.0.1:18789. It runs as *one human account* rather than
#     as a daemon user, because the whole point of it is reaching that
#     account's files and tools. Read the security note on
#     `local.ai.openclaw.enable` in options.nix before turning it on — it is
#     not a rhetorical warning, nixpkgs ships the package with a
#     `knownVulnerabilities` entry and this module has to disarm that check to
#     install it at all.
#
# Nothing here opens a firewall port. All three listen on 127.0.0.1 and are
# meant to be reached from this machine or through the tailnet that base.nix
# already brings up — `tailscale serve` in front of one of these is the
# supported way to use it from a phone, and is a decision to make deliberately
# rather than a default.
#
# The GPU, and the first build
# ----------------------------
# `local.ai.ollama.acceleration` defaults to reading
# `services.xserver.videoDrivers`: nvidia gives `ollama-cuda`, amdgpu gives
# `ollama-rocm`, anything else gives `ollama-cpu`. That is the right default
# and it is also the expensive one — **cache.nixos.org does not carry
# ollama-cuda**, because Hydra doesn't build against unfree CUDA, so the first
# rebuild after enabling this compiles it here. Budget half an hour or more,
# once. `nix.settings.substituters` can be pointed at the cuda-maintainers
# cachix if that is not acceptable; `acceleration = "cpu"` is the way to try
# the rest of this module without waiting for it.
#
# Sharing the card with a guest
# -----------------------------
# ollama pins the NVIDIA driver in memory for as long as a model is loaded,
# and modules/nixos/gpu-passthrough.nix cannot unload a driver something else
# is holding. So this module adds its own units to that hook's
# `stopServices` list, which is exactly the case its `example` was written
# for. The two modules are otherwise independent; enabling either without the
# other is fine.
let
  cfg = config.local.ai;

  # `local.ai.enable` is the master switch and the three sub-switches only
  # mean anything under it, so each of them is written down once here rather
  # than as a conjunction at every use. It also leaves the warnings below
  # outside any `mkIf`, which is what lets them say something about a
  # sub-switch turned on with the master switch off — the one arrangement
  # that would otherwise do nothing at all, quietly.
  ollamaOn = cfg.enable && cfg.ollama.enable;
  webuiOn = cfg.enable && cfg.webui.enable;
  openclawOn = cfg.enable && cfg.openclaw.enable;

  ollamaUrl = "http://127.0.0.1:${toString cfg.ollama.port}";

  # "auto" reads the same list the desktop's driver comes from, so a machine
  # that has already said "nvidia" once doesn't have to say "cuda" here too.
  acceleration =
    if cfg.ollama.acceleration != "auto" then
      cfg.ollama.acceleration
    else if lib.elem "nvidia" config.services.xserver.videoDrivers then
      "cuda"
    else if lib.elem "amdgpu" config.services.xserver.videoDrivers then
      "rocm"
    else
      "cpu";

  ollamaPackage =
    {
      cuda = pkgs.ollama-cuda;
      rocm = pkgs.ollama-rocm;
      vulkan = pkgs.ollama-vulkan;
      cpu = pkgs.ollama-cpu;
    }
    .${acceleration};

  # The config OpenClaw gets on a machine that has never run it, and never
  # again after that. See the launcher below for why it is a seed rather than
  # a generated file.
  #
  # Deliberately tiny. OpenClaw validates its config strictly — an unknown key
  # or a mistyped value doesn't warn, it stops the gateway booting — so this
  # writes the two things that can't be discovered at runtime and leaves every
  # other default alone. `${OPENCLAW_GATEWAY_TOKEN}` is OpenClaw's own
  # environment substitution, not Nix's: the token stays in a file next to the
  # config rather than in the config, and never enters the store.
  openclawSeed =
    {
      gateway.auth.token = "\${OPENCLAW_GATEWAY_TOKEN}";
    }
    // lib.optionalAttrs (cfg.openclaw.model != null) {
      agents.defaults.model.primary = cfg.openclaw.model;
    };

  openclawSeedFile = pkgs.writeText "openclaw-seed.json" (builtins.toJSON openclawSeed);

  # What the user service actually runs.
  #
  # A wrapper rather than a bare `ExecStart = openclaw gateway` because two
  # things have to exist before the gateway will start and neither can come
  # from the store:
  #
  #   1. **An auth token.** The gateway requires authentication by default and
  #      onboarding normally generates the token. Nothing here is going to put
  #      a secret in a world-readable /nix/store path, so it is generated on
  #      first start into ~/.openclaw/gateway.env, mode 600, and read back
  #      from there on every start after that.
  #
  #   2. **A config file.** OpenClaw *owns* ~/.openclaw/openclaw.json: the
  #      Control UI writes to it, `openclaw config set` writes to it, and the
  #      gateway hot-reloads it. Upstream explicitly says not to make it a
  #      symlink, because OpenClaw replaces it by rename. So this seeds the
  #      file when it is absent and never touches it again — which means
  #      **changing `local.ai.openclaw.model` after the first start does
  #      nothing**; use `openclaw models set ollama/<model>` for that. The
  #      port is passed on the command line instead, so it stays a property of
  #      the unit and can't go stale.
  openclawLauncher = pkgs.writeShellApplication {
    name = "openclaw-gateway";

    runtimeInputs = with pkgs; [
      coreutils # mkdir, install, printf
      openssl # the token
      openclaw
    ];

    text = ''
      stateDir="$HOME/.openclaw"
      configFile="$stateDir/openclaw.json"
      envFile="$stateDir/gateway.env"

      mkdir -p "$stateDir"

      if [ ! -e "$envFile" ]; then
        ( umask 077; printf 'OPENCLAW_GATEWAY_TOKEN=%s\n' "$(openssl rand -hex 32)" > "$envFile" )
        echo "generated a gateway token in $envFile"
      fi

      # Also the place to put provider credentials by hand — OPENAI_API_KEY,
      # ANTHROPIC_API_KEY and friends — for anything that isn't the local
      # ollama. It is sourced, not parsed, so `export` is optional and
      # comments are fine.
      set -a
      # shellcheck disable=SC1090,SC1091
      . "$envFile"
      set +a

      if [ ! -e "$configFile" ]; then
        # install rather than cp: the store copy is read-only, and OpenClaw
        # has to be able to write its own config.
        install -m 600 ${openclawSeedFile} "$configFile"
        echo "wrote a starting config to $configFile"
      fi

      exec openclaw gateway --port ${toString cfg.openclaw.port}
    '';
  };
in
{
  # local.* lives in its own module so this one can stay a config attrset.
  imports = [ ./options.nix ];

  config = lib.mkMerge [

    # --- the model runner ---------------------------------------------
    (lib.mkIf ollamaOn {
      services.ollama = {
        enable = true;
        package = ollamaPackage;

        # Loopback. Reaching this from another machine is a `tailscale serve`
        # decision, not a default — see the header.
        host = "127.0.0.1";
        inherit (cfg.ollama) port;

        loadModels = cfg.ollama.models;
        syncModels = cfg.ollama.pruneUndeclaredModels;
      };
    })

    # --- the chat window ----------------------------------------------
    (lib.mkIf webuiOn {
      services.open-webui = {
        enable = true;
        host = "127.0.0.1";
        inherit (cfg.webui) port;

        environment =
          {
            # The nixpkgs module's own default for this option, restated
            # because setting `environment` at all *replaces* that default
            # rather than merging with it — leave these out and the telemetry
            # comes back on.
            SCARF_NO_ANALYTICS = "True";
            DO_NOT_TRACK = "True";
            ANONYMIZED_TELEMETRY = "False";

            # Nothing here has an OpenAI key, and leaving the integration on
            # costs a connection attempt to api.openai.com on every start and
            # a spinner on the model list. Put a key in `extraEnvironment`
            # along with `ENABLE_OPENAI_API = "True"` to use both.
            ENABLE_OPENAI_API = "False";
          }
          // lib.optionalAttrs ollamaOn {
            # The current spelling. `OLLAMA_API_BASE_URL` is the older one and
            # wants the `/api` suffix; Open WebUI derives this from that when
            # only the old name is set, but new config should use this.
            OLLAMA_BASE_URL = ollamaUrl;
          }
          // cfg.webui.extraEnvironment;
      };
    })

    # --- the agent ------------------------------------------------------
    (lib.mkIf openclawOn {
      # nixpkgs marks openclaw insecure, and it is right to: the program
      # feeds untrusted text — a message from a chat channel, a web page it
      # fetched — to a model that can then run tools on this account. Prompt
      # injection is not a hypothetical against a design like that.
      #
      # Refusing to build it is nixpkgs doing its job, so this says out loud
      # which package is being let through and why, rather than turning the
      # check off. Matched on the *name*, not `permittedInsecurePackages`'s
      # `openclaw-<version>`, so a `nix flake update` doesn't break the
      # rebuild with an error about a version number nobody chose.
      #
      # Note this replaces nixpkgs' default predicate, which is the one that
      # reads `permittedInsecurePackages`. Nothing else in this repo uses that
      # list; if something ever does, this predicate is where it has to be
      # taught about it. `NIXPKGS_ALLOW_INSECURE=1` still works either way.
      nixpkgs.config.allowInsecurePredicate = pkg: lib.getName pkg == "openclaw";

      # For `openclaw doctor`, `openclaw onboard`, `openclaw models list` and
      # the rest of the CLI — the same binary the service runs.
      environment.systemPackages = [ pkgs.openclaw ];

      # A *user* service, not a system one.
      #
      # OpenClaw is somebody's assistant. It wants their home directory, their
      # shell tools, their git checkouts and their session; run it under
      # DynamicUser with ProtectHome and there is nothing left for it to do.
      # So it runs as the account named in `local.ai.openclaw.user`, with that
      # account's own systemd manager, and this module deliberately adds none
      # of the usual sandboxing directives — they would each remove a
      # capability the program exists to have. The isolation that does apply
      # is the account boundary: it is that user and no more, and on this
      # machine that user isn't root.
      #
      # NixOS has one systemd --user generation for the whole machine, so the
      # unit is defined for every account and `ConditionUser=` picks the one
      # it is meant for. Everyone else's user manager skips it with a line in
      # the journal and no failure.
      systemd.user.services.openclaw = {
        description = "OpenClaw gateway (local AI agent)";
        documentation = [ "https://docs.openclaw.ai/" ];
        wantedBy = [ "default.target" ];

        unitConfig.ConditionUser = cfg.openclaw.user;

        # The agent shells out — that is most of what it is for — so give it
        # the machine's packages and this account's home-manager profile
        # rather than the near-empty PATH a user unit starts with.
        path = [
          config.system.path
          "/etc/profiles/per-user/${cfg.openclaw.user}"
        ];

        environment = lib.optionalAttrs ollamaOn {
          # Opts the bundled Ollama provider in. A loopback or LAN host needs
          # no real credential and `ollama-local` is upstream's marker for
          # exactly that case; it is not a secret and there is no account
          # behind it.
          OLLAMA_API_KEY = "ollama-local";
        };

        serviceConfig = {
          Type = "simple";
          ExecStart = lib.getExe openclawLauncher;

          # Optional, and separate from ~/.openclaw/gateway.env on purpose:
          # this one is for a file something else manages — a secrets tool, a
          # path outside the home directory. Leading `-` so a missing file is
          # not a failed start.
          EnvironmentFile = lib.optional (
            cfg.openclaw.environmentFile != null
          ) "-${toString cfg.openclaw.environmentFile}";

          Restart = "on-failure";
          RestartSec = 10;
        };
      };

      # Without lingering, the gateway is only up while that account has a
      # session — which is the right default for an assistant on a desktop,
      # and the wrong one for a machine you message from a phone.
      #
      # `mkIf` on the whole attrset rather than on `linger` alone, so the
      # default case adds no key to `users.users` at all. Written the other
      # way it would *declare* the account — an attrsOf submodule instantiates
      # for any name mentioned — which would turn a typo in
      # `local.ai.openclaw.user` into a half-built second user and defeat the
      # assertion below, whose whole job is to catch that typo.
      users.users = lib.mkIf cfg.openclaw.linger {
        ${cfg.openclaw.user}.linger = true;
      };
    })

    # --- everything else ------------------------------------------------
    {
      # Hand the GPU-passthrough hook the units that hold the card, so a guest
      # can actually get it. Harmless when that module is off: nothing reads
      # this list unless `local.virtualisation.singleGpuPassthrough.enable` is
      # on, and the hook only stops units that are running.
      #
      # ollama is the one that matters — a loaded model keeps the NVIDIA
      # driver pinned and the hook's five attempts to unload it will all fail,
      # which refuses the VM. Open WebUI is here because its torch/onnx
      # embedding path can take a CUDA context of its own; the cost of
      # stopping it needlessly is a web page that reconnects, and the cost of
      # not stopping it when it mattered is a guest that won't start.
      local.virtualisation.singleGpuPassthrough.stopServices =
        lib.optional ollamaOn "ollama.service"
        ++ lib.optional webuiOn "open-webui.service";

      assertions = [
        {
          # Both halves matter. The account may be missing entirely, in which
          # case the `?` is false and the second half is never reached; or it
          # may exist only because `linger` above mentioned it, in which case
          # it is a submodule full of defaults with no uid and no home, and
          # `isNormalUser` is what tells the two apart. Either way the gateway
          # would have nowhere to keep its config, token and workspace.
          assertion =
            !openclawOn
            || (
              config.users.users ? ${cfg.openclaw.user}
              && config.users.users.${cfg.openclaw.user}.isNormalUser
            );
          message = ''
            local.ai.openclaw.user is "${cfg.openclaw.user}", which isn't a
            normal account on this machine. The gateway runs inside that
            user's own systemd manager and needs a real home directory —
            declare the account in modules/nixos/users.nix, or point this at
            one that already exists.
          '';
        }
      ];

      warnings =
        lib.optional (!cfg.enable && (cfg.ollama.enable || cfg.webui.enable || cfg.openclaw.enable)) ''
          local.ai.enable is off, so nothing under local.ai is configured —
          but one of its sub-switches (ollama, webui, openclaw) is on. They
          only mean anything under the master switch, so as written this host
          has no model server, no chat window and no agent. Set
          local.ai.enable = true, or turn the sub-switch back off.
        ''
        ++ lib.optional (openclawOn && ollamaOn && cfg.ollama.port != 11434) ''
          local.ai.ollama.port is ${toString cfg.ollama.port}, but OpenClaw's
          bundled Ollama provider only discovers a server on the default
          11434. The gateway will start and find no local models. Either put
          the port back, or add a provider block naming the real base URL:

              openclaw config set models.providers.ollama.baseUrl "${ollamaUrl}"
              openclaw config set models.providers.ollama.api ollama
        ''
        ++ lib.optional (openclawOn && !ollamaOn && cfg.openclaw.environmentFile == null) ''
          local.ai.openclaw is on with no local model server and no
          environmentFile, so the gateway has nothing to think with unless you
          have already put provider credentials in ~/.openclaw/gateway.env or
          run `openclaw onboard`. Turn local.ai.ollama on to keep it local.
        '';
    }
  ];
}
