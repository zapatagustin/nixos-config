{
  description = "multi-host NixOS flake (surface + thinkpad)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent.url = "github:NousResearch/hermes-agent";
    # Claude Code + opencode config. Single source of truth: this flake used to
    # carry its own copy under modules/home-manager/{claude-code,opencode},
    # which drifted from it silently.
    ecomono = {
      url = "github:zapatagustin/ecomono";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, chaotic, ... }@inputs:
    let
      mkHost = hostname:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs hostname; username = hostname; };
          modules = [
            ./hosts/${hostname}/default.nix
            chaotic.nixosModules.default
            inputs.stylix.nixosModules.stylix
            inputs.sops-nix.nixosModules.sops
            inputs.hermes-agent.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.useUserPackages = true;
              # back up (instead of clobber) pre-existing unmanaged dotfiles, e.g. ~/.zshrc -> ~/.zshrc.hm-bak
              home-manager.backupFileExtension = "hm-bak";
              home-manager.extraSpecialArgs = { inherit inputs hostname; username = hostname; };

              home-manager.users.${hostname} = import ./modules/home-manager/home.nix;
            }
          ];
        };

      nixosConfigurations = {
        surface = mkHost "surface";
        thinkpad = mkHost "thinkpad";
      };

      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # Validate a host's generated Hyprland Lua config with the real
      # `Hyprland --verify-config` binary (not just a Lua syntax check): it also
      # catches schema errors in hl.config/hl.bind/etc. Works fine inside the Nix
      # build sandbox -- it only needs a writable XDG_RUNTIME_DIR, no display/
      # dbus/wayland socket. Currently `nix flake check` validates neither this
      # nor the QML below, so either fails only at runtime (compositor emergency
      # mode / a dead quickshell bar).
      #
      # The verifying binary comes from the host's own config, not from a bare
      # nixpkgs. That matters because the chaotic overlay is in each host's module
      # list, so programs.hyprland.package already reflects whatever it resolves to
      # -- the check therefore parses with the exact binary uwsm launches
      # (withUWSM = true in modules/wm/hyprland.nix), and stays correct if chaotic
      # ever repins Hyprland away from nixpkgs. Verifying with a schema from a
      # different build than the one running is the failure this avoids.
      hyprlandConfigCheck = hostname:
        let
          hostCfg = nixosConfigurations.${hostname}.config;
          luaConfig = hostCfg.home-manager.users.${hostname}
            .xdg.configFile."hypr/hyprland.lua".source;
        in
        pkgs.runCommand "hyprland-config-${hostname}"
          { nativeBuildInputs = [ hostCfg.programs.hyprland.package ]; } ''
          export XDG_RUNTIME_DIR=$TMPDIR/xdgrt
          mkdir -p -m700 "$XDG_RUNTIME_DIR"
          cp ${luaConfig} cfg.lua
          Hyprland --verify-config -c ./cfg.lua | tee $out
          grep -q "config ok" $out
        '';

      # qmllint over the quickshell bar QML. -I points at Qt's own qml modules
      # and at Quickshell's (derived from the nixpkgs `quickshell` package, not a
      # hardcoded store path), so imports like `Quickshell.Hyprland` resolve and
      # don't drown real findings in a wall of unresolved-import noise.
      # Two categories are fatal:
      #   --import error          "X is not a type" -- a misspelled or unresolvable
      #                           component, which takes down the whole shell.
      #   --missing-property error a property that does not exist on the type it is
      #                           read from. This one earned its place: the tree had
      #                           8 live instances, all silently broken. Seven read
      #                           .containsMouse off a HoverHandler (that is a
      #                           MouseArea property; HoverHandler has .hovered), so
      #                           every hover highlight evaluated `undefined ? a : b`
      #                           and never lit up. The eighth called .popup() on a
      #                           QsMenuAnchor, whose method is .open(), so the tray
      #                           icon's right-click menu never opened. None of it
      #                           errored at runtime; the UI just quietly did nothing.
      #
      # Everything else stays at qmllint's default warning level, which does not fail
      # the build, because the known-good tree trips them for reasons outside this
      # config's control. Deliberately NOT covered, so nobody mistakes them for gated:
      #   [uncreatable-type]  PanelWindow -- creatable in Quickshell, qmllint can't tell
      #   [unresolved-type]   QsMenuAnchor.menu's DBusMenuHandle isn't exposed declaratively
      #   [unqualified]       ~116 hits; wants `pragma ComponentBehavior: Bound` everywhere
      #   [unused-imports]    cosmetic
      #
      # Known gap: qmllint resolves same-directory components by filename regardless
      # of what qmldir declares, so it does NOT catch a component missing from qmldir
      # while its .qml file is still present -- verified, still exits 0. That is the
      # "X is not a type" failure the qmldir comment warns about, and
      # quickshellBarQmldir below is what actually covers it.
      quickshellBarQmllint =
        let
          barDir = ./modules/home-manager/wm/hyprland/quickshell/bar;
        in
        pkgs.runCommand "quickshell-bar-qmllint"
          { nativeBuildInputs = [ pkgs.qt6.qtdeclarative ]; } ''
          # qmllint writes findings to stderr, so merge it in: without 2>&1 the
          # log is empty and only the exit code carries any signal. pipefail so
          # tee's success doesn't mask qmllint's failure.
          set -o pipefail
          qmllint --import error --missing-property error \
            -I ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml \
            -I ${pkgs.quickshell}/lib/qt-6/qml \
            -I ${barDir} \
            ${barDir}/*.qml 2>&1 | tee $out
        '';

      # Closes qmllint's blind spot above. Once a directory has a qmldir, Qt stops
      # auto-discovering siblings by filename, so a .qml that is not listed fails
      # with "X is not a type" and takes down the whole shell -- not one widget.
      # qmllint cannot see this because it resolves same-directory components by
      # filename either way, so compare the two lists directly. shell.qml is the
      # entry point (loaded via `quickshell -p`, never imported as a type), so it
      # is the one file that must NOT be listed.
      quickshellBarQmldir =
        let
          barDir = ./modules/home-manager/wm/hyprland/quickshell/bar;
        in
        pkgs.runCommand "quickshell-bar-qmldir" { } ''
          cd ${barDir}

          # The filename is the last field of a qmldir line ("Name 1.0 Name.qml",
          # "singleton Paths 1.0 Paths.qml"). Collect them space-delimited so
          # membership below is an exact string compare -- interpolating a filename
          # into a regex would make its dot match any character.
          declared=" $(awk '$NF ~ /\.qml''$/ { print $NF }' qmldir | tr '\n' ' ') "

          for f in *.qml; do
            [ "$f" = shell.qml ] && continue
            case "$declared" in
            *" $f "*) ;;
            *) echo "$f exists but is not declared in qmldir" >&2; exit 1 ;;
            esac
          done

          # for over command substitution, not `grep | while read`: a subshell's
          # exit would not fail this script.
          for f in $declared; do
            [ -f "$f" ] || { echo "qmldir declares $f, which does not exist" >&2; exit 1; }
          done

          echo "qmldir and *.qml agree" > $out
        '';
    in
    {
      inherit nixosConfigurations;

      formatter.x86_64-linux = pkgs.nixpkgs-fmt;

      checks.x86_64-linux = {
        hyprland-lua-surface = hyprlandConfigCheck "surface";
        hyprland-lua-thinkpad = hyprlandConfigCheck "thinkpad";
        quickshell-bar-qmllint = quickshellBarQmllint;
        quickshell-bar-qmldir = quickshellBarQmldir;
      };
    };
}
