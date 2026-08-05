{
  description = "multi-host NixOS flake (surface + thinkpad)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # chaotic (CachyOS packages, incl. the kernel). It tracks nixos-unstable itself,
    # so before these follows its nixpkgs merely HAPPENED to match ours whenever both
    # were updated in the same run — a partial `nix flake update` would have split
    # them and pulled a second full nixpkgs into the closure. Its home-manager input
    # only feeds chaotic's own homeManagerModules, which this repo does not use (it
    # takes chaotic.nixosModules.default).
    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
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
    # Claude Code + opencode config. Single source of truth: this flake used to
    # carry its own copy under modules/home-manager/{claude-code,opencode},
    # which drifted from it silently.
    ecomono = {
      url = "github:zapatagustin/ecomono";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Doom Emacs built by nix (see modules/home-manager/editors/emacs). Replaces
    # the old writable ~/.config/emacs checkout, whose `doom sync` cloned 142
    # unpinned straight.el repos: nothing recorded what they resolved to, so a
    # rebuild got whatever upstream shipped that day. Its own doomemacs input is
    # github:doomemacs/core, the same v3 core this config used to clone.
    #
    # nixpkgs.follows = "" rather than "nixpkgs" (as upstream's README suggests):
    # the home-manager module builds against the consuming config's pkgs, so this
    # input's nixpkgs would only feed its own checks/devShell. Dropping it keeps it
    # out of the lockfile instead of merely deduplicating it. Its emacs-overlay
    # input already pins nixpkgs.follows = "" itself, so there is still exactly
    # one nixpkgs in the lockfile.
    nix-doom-emacs-unstraightened = {
      url = "github:marienz/nix-doom-emacs-unstraightened";
      inputs.nixpkgs.follows = "";
    };
    # Prebuilt nix-index database. programs.nix-index has been enabled since
    # forever, but the database it needs is generated locally and never was, so
    # every unknown command printed an I/O error instead of naming the package,
    # and `comma` was broken for the same reason. Generating it by hand is a manual
    # step that goes stale as nixpkgs moves; this input ships it and updates with
    # `nix flake update`.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, chaotic, ... }@inputs:
    let
      # Where this repo is checked out on the host. surface keeps it under
      # ~/personal; every other host uses ~/nixos-config. Defined once and
      # threaded into BOTH layers, so NH_FLAKE (hosts/host.nix) and the zsh
      # rebuild aliases (shells/zsh/zsh.nix) cannot drift apart — the aliases
      # used to hardcode surface's path and rebuilt the wrong host on thinkpad.
      flakePathFor = hostname:
        if hostname == "surface"
        then "/home/surface/personal/nixos-config"
        else "/home/${hostname}/nixos-config";

      mkHost = hostname:
        let flakePath = flakePathFor hostname; in
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs hostname flakePath; username = hostname; };
          modules = [
            ./hosts/${hostname}/default.nix
            chaotic.nixosModules.default
            inputs.stylix.nixosModules.stylix
            inputs.sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useUserPackages = true;
              # back up (instead of clobber) pre-existing unmanaged dotfiles, e.g. ~/.zshrc -> ~/.zshrc.hm-bak
              home-manager.backupFileExtension = "hm-bak";
              home-manager.extraSpecialArgs = { inherit inputs hostname flakePath; username = hostname; };

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
      #
      # `variant` selects which home-manager generation's Lua to verify. The
      # borders now come from base16, so the light specialisation emits DIFFERENT
      # colour literals -- checking only the parent would leave the palette you get
      # from `set-theme light` unverified.
      hyprlandConfigCheck = hostname: variant:
        let
          hostCfg = nixosConfigurations.${hostname}.config;
          hmCfg = hostCfg.home-manager.users.${hostname};
          cfgFor = if variant == "light" then hmCfg.specialisation.light.configuration else hmCfg;
          luaConfig = cfgFor.xdg.configFile."hypr/hyprland.lua".source;
        in
        pkgs.runCommand "hyprland-config-${hostname}-${variant}"
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
      # Formatting + lint gates. `nix flake check` previously validated the
      # generated Hyprland/QML output but nothing about the Nix source itself, so
      # 13 of 40 files had drifted out of nixpkgs-fmt and both linters were dirty.
      #
      # hardware-configuration.nix is excluded from all three: nixos-generate-config
      # writes it wholesale (see CLAUDE.md), so holding it to repo rules means the
      # next hardware change breaks the build for reasons nobody caused.
      generatedNix = "hardware-configuration.nix";
      nixSources = pkgs.lib.fileset.toSource {
        root = ./.;
        fileset = pkgs.lib.fileset.unions [
          (pkgs.lib.fileset.fileFilter (f: f.hasExt "nix") ./.)
          ./statix.toml
        ];
      };

      nixpkgsFmtCheck = pkgs.runCommand "nixpkgs-fmt-check"
        { nativeBuildInputs = [ pkgs.nixpkgs-fmt pkgs.findutils ]; } ''
        cd ${nixSources}
        set -o pipefail # decide on nixpkgs-fmt's exit code, not on its wording
        # nixpkgs-fmt has no exclude flag, so hand it an explicit file list.
        mapfile -d "" files < <(find . -name '*.nix' ! -name '${generatedNix}' -print0)
        # An empty list would make `nixpkgs-fmt --check` with no arguments exit
        # non-zero with a message matching nothing, which an output-grep version of
        # this check read as success. Fail loudly instead of checking nothing.
        if [ "''${#files[@]}" -eq 0 ]; then
          echo "no .nix files found under the check source — the fileset is wrong" >&2
          exit 1
        fi
        if ! nixpkgs-fmt --check "''${files[@]}" 2>&1 | tee $out; then
          echo "run: nix fmt" >&2
          exit 1
        fi
      '';

      statixCheck = pkgs.runCommand "statix-check"
        { nativeBuildInputs = [ pkgs.statix ]; } ''
        cd ${nixSources}
        # pipefail so tee's success doesn't mask statix's failure -- same reason as
        # quickshellBarQmllint above. Without it this gate silently passes on every
        # finding, which is exactly how it was first written.
        set -o pipefail
        # Reads statix.toml from the source root: repeated_keys is deliberately
        # disabled there, with the reasoning.
        statix check . 2>&1 | tee $out
      '';

      # Only the two generated hyprland.lua wrappers are excluded, and only because
      # they are generated. Every hand-written .nix in the repo is linted, including
      # modules/secrets/sops.nix, which used to sit on this list for an unused
      # `config` argument that has since been dropped.
      deadnixCheck = pkgs.runCommand "deadnix-check"
        { nativeBuildInputs = [ pkgs.deadnix ]; } ''
        cd ${nixSources}
        set -o pipefail # tee must not mask --fail
        # --exclude takes many values after ONE flag and cannot be repeated, so the
        # trailing path needs `--` or it gets swallowed into the exclude list.
        deadnix --fail \
          --exclude ./hosts/surface/${generatedNix} \
                    ./hosts/thinkpad/${generatedNix} \
          -- . 2>&1 | tee $out
      '';

      # Enforces the two invariants that make it safe for the light specialisation
      # to skip reloadSystemd and ecomonoAgents (modules/home-manager/stylix.nix).
      # Without this the skips are a comment nobody rechecks: the day someone makes
      # a user unit depend on the palette, a theme switch would stop restarting it
      # and the reason would be invisible. That is the exact comment-rot this repo
      # has been bitten by three times.
      themeSpecialisationInvariants = hostname:
        let
          hm = nixosConfigurations.${hostname}.config.home-manager.users.${hostname};
          # Same single source the two stylix instances read, so the hex check below
          # is pinned to the actual scheme rather than to a second copy of the path.
          inherit ((import ./modules/theme/tokens.nix pkgs)) scheme;
          dark = hm.home.activationPackage;
          light = hm.specialisation.light.configuration.home.activationPackage;
          darkSpec = hm.specialisation.dark.configuration.home.activationPackage;
        in
        pkgs.runCommand "theme-specialisation-invariants-${hostname}" { } ''
          set -o pipefail
          {
            echo "== systemd user units must be identical =="
            d=${dark}/home-files/.config/systemd/user
            l=${light}/home-files/.config/systemd/user
            if [ -e "$d" ] || [ -e "$l" ]; then
              diff -rq "$d" "$l" || {
                echo "A user unit differs between the dark and light generations." >&2
                echo "reloadSystemd is skipped in the light specialisation precisely" >&2
                echo "because nothing there could change. Stop skipping it, or keep" >&2
                echo "the unit palette-independent." >&2
                exit 1
              }
            fi
            echo "ok"

            echo "== home-path must be identical (no package differs by palette) =="
            [ "${dark}/home-path" = "${light}/home-path" ] || \
              [ "$(readlink -f ${dark}/home-path)" = "$(readlink -f ${light}/home-path)" ] || {
                echo "The two generations install different packages, so a theme" >&2
                echo "switch is no longer just a relink and the timing reasoning" >&2
                echo "in stylix.nix no longer holds." >&2
                exit 1
              }
            echo "ok"

            echo "== hyprland.lua must NOT differ between the two palettes =="
            # This one is not about the activation skips: it is what keeps a theme
            # switch from reloading Hyprland at all. home-manager attaches an
            # onChange hook to .config/hypr/hyprland.lua that runs `hyprctl reload
            # config-only`, and that reload resets the external monitors' DDC
            # brightness to 100% -- measured on the hardware, 41 -> 100 on both,
            # with setup-monitors.sh stopped so nothing else could be blamed. The
            # externals do not persist a DDC write and revert to their OSD default
            # when the link is re-initialised. So the border colours are literals in
            # wm/hyprland/default.nix and set-theme.sh pushes the live palette over
            # `hyprctl eval`. Put a config.lib.stylix.colors reference back into that
            # file and the switch silently starts reloading again.
            diff -q ${dark}/home-files/.config/hypr/hyprland.lua \
                    ${light}/home-files/.config/hypr/hyprland.lua || {
              echo "hyprland.lua differs between the dark and light generations, so" >&2
              echo "home-manager's onChange hook will reload Hyprland on every theme" >&2
              echo "switch. Keep the colours in that file static and let set-theme.sh" >&2
              echo "push the palette at runtime." >&2
              exit 1
            }
            echo "ok"

            echo "== hyprland's own config watcher must stay off =="
            # The sibling of the check above. Keeping hyprland.lua identical stops
            # home-manager's onChange hook from firing, but Hyprland ALSO watches the
            # config path itself, and linkGeneration moves that path on every switch
            # (the home-manager-files hash changes because the other palette files in
            # it did). Measured: two relinks to byte-identical content produced two
            # reloads. Under nix the watcher can only ever be a false positive -- the
            # file is an immutable store symlink, so no hand-edit can reach it.
            grep -q 'disable_autoreload *= *true' \
              ${dark}/home-files/.config/hypr/hyprland.lua || {
              echo "misc.disable_autoreload is no longer set in hyprland.lua, so" >&2
              echo "Hyprland will reload itself every time home-manager relinks the" >&2
              echo "config -- i.e. on every theme switch, blanking the externals and" >&2
              echo "resetting their DDC brightness." >&2
              exit 1
            }
            echo "ok"

            echo "== those static hexes must still be the dark palette =="
            # The literals only stay correct as long as nobody changes the scheme in
            # modules/theme/tokens.nix. Pin them to the yaml stylix itself reads
            # rather than to a comment.
            for pair in base0A:fabd2f base09:fe8019 base01:3c3836; do
              key=''${pair%%:*}; want=''${pair##*:}
              # Entries look like `  base0A: "#fabd2f" # yellow` -- indented, quoted,
              # hash-prefixed and trailing-commented, so anchor on the key and pull
              # the six hex digits out of the middle rather than matching a shape.
              got=$(sed -n "s/^[[:space:]]*$key:[^0-9a-fA-F]*\([0-9a-fA-F]\{6\}\).*/\1/p" \
                    ${scheme "dark"} | head -n1)
              [ "$got" = "$want" ] || {
                echo "$key is $got in the dark scheme but wm/hyprland/default.nix" >&2
                echo "hardcodes $want. Update the literal, or the parse-time border" >&2
                echo "colour stops matching the palette everything else uses." >&2
                exit 1
              }
              grep -qF "rgba($want" ${dark}/home-files/.config/hypr/hyprland.lua || {
                echo "$key ($want) is no longer present in the generated hyprland.lua." >&2
                exit 1
              }
            done
            echo "ok"

            echo "== the dark specialisation must be a faithful stand-in for the parent =="
            # set-theme activates specialisation/dark rather than the parent, to get
            # the trimmed activation. That is only correct if it deploys exactly the
            # same files the parent would.
            diff -rq ${dark}/home-files ${darkSpec}/home-files || {
              echo "specialisation.dark deploys different files than the parent, so" >&2
              echo "switching to dark would no longer restore the rebuilt state." >&2
              exit 1
            }
            echo "ok"
          } | tee $out
        '';

      # Structural checks no off-the-shelf linter covers: orphaned .nix files,
      # dangling ~/.config/hypr script references, host-name literals in shared HM
      # modules. Same script the pre-commit hook runs, so the two cannot disagree.
      repoLint = pkgs.runCommand "repo-lint"
        { nativeBuildInputs = [ pkgs.findutils pkgs.gnugrep pkgs.gnused pkgs.bash ]; } ''
        set -o pipefail
        cp -r ${./.} src && chmod -R u+w src
        bash src/scripts/repo-lint.sh 2>&1 | tee $out
      '';

      # The hypr scripts deployed via xdg.configFile never pass through
      # writeShellApplication, so unlike the wrapped ones (brightness,
      # monitor-watcher, audio-device-watcher, set-theme) nothing ever ran
      # shellcheck over them. This closes that half of the split without changing
      # how they are deployed -- they must stay flat in ~/.config/hypr because they
      # source each other via `dirname $0`.
      hyprScriptsShellcheck =
        let scripts = ./modules/home-manager/wm/hyprland/scripts; in
        pkgs.runCommand "hypr-scripts-shellcheck"
          { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
          # Exclusions live in ../.shellcheckrc, with the reason for each. Passed
          # via --rcfile because the scripts are read from the store, where
          # shellcheck's own upward search would never find the repo's rcfile —
          # and because scripts/hooks/pre-commit passes the same file, so the two
          # callers cannot drift (the list used to be duplicated in both).
          set -o pipefail # tee must not mask shellcheck's exit code
          shellcheck --shell=bash --external-sources \
            --rcfile=${./.shellcheckrc} \
            ${scripts}/*.sh 2>&1 | tee $out
        '';
    in
    {
      inherit nixosConfigurations;

      formatter.x86_64-linux = pkgs.nixpkgs-fmt;

      checks.x86_64-linux = {
        hyprland-lua-surface = hyprlandConfigCheck "surface" "dark";
        hyprland-lua-thinkpad = hyprlandConfigCheck "thinkpad" "dark";
        hyprland-lua-surface-light = hyprlandConfigCheck "surface" "light";
        hyprland-lua-thinkpad-light = hyprlandConfigCheck "thinkpad" "light";
        quickshell-bar-qmllint = quickshellBarQmllint;
        quickshell-bar-qmldir = quickshellBarQmldir;
        nixpkgs-fmt = nixpkgsFmtCheck;
        statix = statixCheck;
        deadnix = deadnixCheck;
        hypr-scripts-shellcheck = hyprScriptsShellcheck;
        repo-lint = repoLint;
        theme-invariants-surface = themeSpecialisationInvariants "surface";
        theme-invariants-thinkpad = themeSpecialisationInvariants "thinkpad";
      };
    };
}
