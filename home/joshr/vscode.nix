{ config, lib, pkgs, ... }:

let
  # Ported from scripts/vscode-extensions.txt in the original dotfiles.
  extensions = [
    "aaron-bond.better-comments"
    "anthropic.claude-code"
    "astro-build.astro-vscode"
    "bbenoist.qml"
    "beardedbear.beardedtheme"
    "brapifra.phpserver"
    "catppuccin.catppuccin-vsc"
    "cweijan.dbclient-jdbc"
    "cweijan.vscode-database-client2"
    "davidanson.vscode-markdownlint"
    "esbenp.prettier-vscode"
    "github.copilot"
    "github.copilot-chat"
    "github.github-vscode-theme"
    "github.vscode-github-actions"
    "github.vscode-pull-request-github"
    "glenn2223.live-sass"
    "icrawl.discord-vscode"
    # Nix language support, and the bridge that lets the editor see a
    # project's direnv shell — without it every import in a flake-managed
    # project reads as unresolved. See "Development environments" in the
    # README.
    "jnoortheen.nix-ide"
    "lakshits11.monokai-pirokai"
    "mathematic.vscode-latex"
    "mhutchie.git-graph"
    "mkhl.direnv"
    "mjpvs.latex-previewer"
    "ms-azuretools.vscode-containers"
    "ms-azuretools.vscode-docker"
    "ms-python.debugpy"
    "ms-python.python"
    "ms-python.vscode-pylance"
    "ms-python.vscode-python-envs"
    "ms-vscode-remote.remote-containers"
    "ms-vscode-remote.remote-ssh"
    "ms-vscode-remote.remote-ssh-edit"
    "ms-vscode.cmake-tools"
    "ms-vscode.cpptools"
    "ms-vscode.cpptools-extension-pack"
    "ms-vscode.cpptools-themes"
    "ms-vscode.remote-explorer"
    "ms-vsliveshare.vsliveshare"
    "oracle.oracle-java"
    "pkief.material-icon-theme"
    "redhat.java"
    "ritwickdey.liveserver"
    "robbowen.synthwave-vscode"
    "shd101wyy.markdown-preview-enhanced"
    "sibiraj-s.vscode-scss-formatter"
    "thenuprojectcontributors.vscode-nushell-lang"
    "theqtcompany.qt-core"
    "usernamehw.errorlens"
    "vscjava.vscode-gradle"
    "vscjava.vscode-java-debug"
    "vscjava.vscode-java-dependency"
    "vscjava.vscode-java-pack"
    "vscjava.vscode-java-test"
    "vscjava.vscode-maven"
    "vscode-icons-team.vscode-icons"
    "whizkydee.material-palenight-theme"
    "yandeu.five-server"
  ];
in
{
  programs.vscode = {
    enable = true;
    profiles.default.userSettings = {
      "window.titleBarStyle" = "custom";
      "workbench.iconTheme" = "material-icon-theme";
      "editor.stickyScroll.enabled" = false;
      "git.enableSmartCommit" = true;
      "github.copilot.enable" = {
        "*" = false;
        plaintext = false;
        markdown = false;
        scminput = false;
        json = true;
        vue = false;
      };
      "settingsSync.ignoredExtensions" = [ "catppuccin.catppuccin-vsc" ];
      "workbench.colorTheme" = "Bearded Theme Monokai Black";
      "markdown-preview-enhanced.previewTheme" = "atom-material.css";
      # NixOS has no /usr/bin/php by default; point this at your nix-provided
      # php if you use fiveServer.
      "fiveServer.php.executable" = "/usr/bin/php";
      "liveServer.settings.donotShowInfoMsg" = true;
      "[jsonc]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "codetogether.userName" = "Josh";
      "git.openRepositoryInParentFolders" = "always";
      "redhat.telemetry.enabled" = false;
      "git.autofetch" = true;
      "terminal.integrated.inheritEnv" = false;
      "githubPullRequests.pullBranch" = "never";
      "terminal.integrated.fontFamily" = "FiraCode Nerd Font Mono";
      "diffEditor.ignoreTrimWhitespace" = false;
      "files.associations" = {
        "*.jas" = "plaintext";
      };
      "settingsSync.ignoredSettings" = [
        "terminal.integrated.defaultProfile.linux"
        "terminal.integrated.profiles.linux"
      ];
      # Nix tooling, pointed at what modules/nixos/development.nix installs
      # rather than letting the extension fetch its own copies. Both names
      # resolve from PATH, so they simply don't work on a host with that
      # module still commented out.
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nil";
      "nix.formatterPath" = "nixfmt";
      "nix.serverSettings" = {
        nil.formatting.command = [ "nixfmt" ];
      };

      "security.workspace.trust.untrustedFiles" = "open";
      "workbench.editor.empty.hint" = "hidden";
      "github.copilot.nextEditSuggestions.enabled" = true;
      "markdown-preview-enhanced.chromePath" = "/home/joshr/.local/bin/chromium";
      "powermode.enabled" = true;
      "files.autoSave" = "afterDelay";
      "workbench.secondarySideBar.defaultVisibility" = "hidden";
      "claudeCode.preferredLocation" = "panel";
    };
  };

  # Extensions aren't declaratively pinned (most aren't packaged in nixpkgs),
  # so mirror the original install-vscode-extensions.sh script: pull them from
  # the marketplace into VS Code's own (mutable) extensions dir.
  #
  # This is gated behind a stamp file keyed on the extension list. Running it
  # unconditionally meant ~60 sequential marketplace round-trips — each one
  # spawning the Electron CLI — on *every* `nixos-rebuild switch`, which added
  # minutes to an otherwise no-op rebuild. Now it only runs when the list above
  # actually changes. To force a re-run, delete the stamp file.
  home.activation.installVscodeExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    let
      code = "${config.programs.vscode.package}/bin/code";
      extList = lib.concatStringsSep " " extensions;
      stamp = "${config.xdg.stateHome}/vscode-extensions.stamp";
      stampFile = pkgs.writeText "vscode-extensions-stamp" (
        builtins.hashString "sha256" extList
      );
    in
    ''
      if [ -x "${code}" ] && ! ${pkgs.diffutils}/bin/cmp -s "${stampFile}" "${stamp}"; then
        for ext in ${extList}; do
          $DRY_RUN_CMD "${code}" --install-extension "$ext" >/dev/null 2>&1 || true
        done
        $DRY_RUN_CMD mkdir -p "$(dirname "${stamp}")"
        $DRY_RUN_CMD cp "${stampFile}" "${stamp}"
      fi
    ''
  );
}
