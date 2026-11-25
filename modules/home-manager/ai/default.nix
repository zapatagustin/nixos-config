# AI agent stack. The Claude Code + opencode config, the shared skills, the
# gentle-ai binary, and the activation script that registers Claude Code plugins
# and user-scope MCP servers all come from the ecomono flake input, imported in
# ../home.nix. This module is only the packages that are not part of that config.
{ config, lib, pkgs, osConfig, inputs, ... }:
let
  # The startup banner the ecomono extension draws in place of omp's welcome
  # (theme/omp-banner.nix): the eDP wallpaper's engraving at terminal size.
  # Handed over by path: the extension reads the PNG, omp places it inline.
  bannerPng = pkgs.callPackage ../../theme/omp-banner.nix {
    wallpaper = pkgs.callPackage ../../theme/dore-dither.nix { } {
      name = "dore-wallpaper";
      plate = pkgs.fetchurl {
        name = "dore-paradise-lost-6-406.jpg";
        url = "https://upload.wikimedia.org/wikipedia/commons/1/1e/6-406_Now_night_her_course_began.jpg";
        hash = "sha256-Jlq3kWZWheMd94Qk1tFygA6ZFnQxtjnowegvYSSls/E=";
      };
      inherit (config.myDesktop.panelResolution) width height;
      bg = "#${config.lib.stylix.colors.base00}";
      fg = "#${config.lib.stylix.colors.base05}";
    };
  };

  # Desktop toast from Claude Code's Stop and Notification hooks, so a session
  # says when it is done or needs input instead of being polled. Reads the hook's
  # JSON on stdin. Stop fires at every turn end; `background_tasks` is non-empty
  # when the turn only paused for background work. That case gets a low-urgency
  # toast rather than silence, so nothing is lost if the field's meaning shifts.
  # Malformed input sends nothing.
  claudeNotify = pkgs.writeShellScript "claude-notify" ''
    jq=${pkgs.jq}/bin/jq
    send=${pkgs.libnotify}/bin/notify-send
    input=$(${pkgs.coreutils}/bin/cat)
    printf '%s' "$input" | $jq -e . >/dev/null 2>&1 || exit 0
    project=$(printf '%s' "$input" | $jq -r '(.cwd // "") | split("/") | last // "session"')
    # Under `vdev` (editors/neovim/lua/mux.lua) this claude runs in the terminal
    # buffer $MUX_BUF of the editor at $NVIM: flag it there, so the editor shows
    # it and can jump to it. Anywhere else both are unset and this does nothing.
    mux() {
      case "''${MUX_BUF:-x}" in *[!0-9]*) return 0 ;; esac
      [ -n "''${NVIM:-}" ] || return 0
      nvim --server "$NVIM" --remote-expr "v:lua.Mux.signal($MUX_BUF, '$1')" >/dev/null 2>&1 || true
    }
    case "$1" in
      stop)
        pending=$(printf '%s' "$input" | $jq -r '(.background_tasks // []) | length')
        if [ "$pending" = 0 ]; then
          mux done
          $send -a "Claude Code" "Claude · $project" "Turn finished"
        else
          $send -a "Claude Code" -u low "Claude · $project" "Waiting on $pending background task(s)"
        fi ;;
      notification)
        message=$(printf '%s' "$input" | $jq -r '.message // "Needs your input"')
        mux blocked
        $send -a "Claude Code" "Claude · $project" "$message" ;;
    esac
  '';
in
{
  home.packages = with pkgs; [
    # Not via its programs.omp module: that one only adds a config.yml that is
    # overwritten on every switch, and omp writes its own settings at runtime.
    #
    # Wrapped like zed (../editors/zed): the OpenCode console key below is read
    # from sops-nix at launch, so it never lands in the nix store or a global
    # session variable. omp reads OPENCODE_API_KEY for both OpenCode Zen and
    # OpenCode Go models (`omp --help`). Same secret as the opencode providers.
    # Ceiling: the exported variable is inherited by the commands omp runs.
    (symlinkJoin {
      name = "omp-sops";
      paths = [ inputs.oh-my-pi.packages.${pkgs.stdenv.hostPlatform.system}.omp ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/omp \
          --run 'export OPENCODE_API_KEY="$(cat ${osConfig.sops.secrets."opencode/opencode-api-key".path} 2>/dev/null)"' \
          --set ECOMONO_OMP_BANNER ${bannerPng}
      '';
    })
  ];

  # Provider credentials, which the ecomono flake deliberately does NOT ship.
  #
  # It used to: every provider carried "apiKey": "{file:/run/secrets/...}". Those
  # paths exist only on a NixOS host running sops-nix, and ecomono's install.sh
  # links opencode.json verbatim instead of patching it the way it patches tui.json
  # -- so on Arch, Debian or a generic install the credentials pointed at files that
  # were never going to be there, and failed with nothing saying why. A flake that
  # installs on four platforms should not hardcode one platform's secret store, so
  # the paths moved HERE, where they are actually true.
  #
  # Note this is the OPPOSITE call from the opencode THEME collision, resolved with
  # a local mkForce in ../stylix.nix. The deciding question is not which repo is
  # more convenient to edit, it is whether the upstream value is right ANYWHERE
  # ELSE: "gruvbox" is a fine default on every other machine, so the override
  # belongs to the consumer; a sops path is wrong on every machine that is not this
  # one, so it belongs nowhere but the consumer.
  #
  # Merging works because programs.opencode.settings takes pkgs.formats.json's
  # type, which merges per key: ecomono pins the models, and only the apiKey leaf
  # comes from here. Verified by evaluating the
  # merged attrset, not assumed.
  #
  # Paths come from osConfig rather than as literals -- home-manager runs as a NixOS
  # module here, so the sops declarations are reachable, and deriving them means the
  # name is written once. A renamed secret breaks at eval instead of resolving to a
  # file that is not there.
  programs.opencode.settings.provider =
    let
      fromSops = secret: {
        options.apiKey = "{file:${osConfig.sops.secrets.${secret}.path}}";
      };
    in
    {
      # OpenCode Go (built-in provider, no block upstream). The ecomono-compress
      # skill's --api pass reads the same secret file directly.
      "opencode-go" = fromSops "opencode/opencode-api-key";
      # OpenCode Zen (provider "opencode", the -free models in the picker): same
      # console key, so Zen stops depending on the credential opencode keeps in
      # its own DB -- that one was the July key and expired.
      opencode = fromSops "opencode/opencode-api-key";
      # Shared with the zed wrapper (../editors/zed), which reads the same file.
      anthropic = fromSops "zed/anthropic-api-key";
      # llama-server on the desktop (RX 6700, Vulkan): the systemd.services
      # .llama-server unit in hosts/desktop/default.nix, reachable only over the
      # tailnet (firewall trusts tailscale0, no LAN port opened). Port 8081, not
      # 8080, which Pi-hole's host-network admin UI holds there. Limits mirror
      # the unit's -c 65536; no apiKey because the server sets none.
      # opencode compacts once a message's tokens reach context - output, and
      # its own system prompt is ~11.6k tokens: at 16k context every message
      # overflowed, so the compaction -> continue cycle never terminated.
      "llama-desktop" = {
        npm = "@ai-sdk/openai-compatible";
        name = "llama-server (desktop)";
        options.baseURL = "http://100.70.43.27:8081/v1";
        models."qwen3.6-35b-uncensored" = {
          name = "Qwen3.6-35B-A3B Uncensored (desktop)";
          limit = {
            context = 65536;
            output = 8192;
          };
        };
      };
    };

  # ecomono-code and cavemem were removed once opencode reached compression
  # parity via the cave-compress plugin (shipped by the ecomono flake): its
  # tool-output/JSON/dedup/char-cap layers cover the same token savings, and
  # ecomono-memory already owns persistent memory. No npm-global tools remain,
  # so the ~/.npm-global prefix + sessionPath were dropped too.

  # opencode dropped: the ecomono module enables programs.opencode, which
  # installs pkgs.opencode itself, so leaving it out of home.packages was not
  # enough. Forcing the module off also skips its ~/.config/opencode files.
  programs.opencode.enable = lib.mkForce false;

  # ~/.claude/settings.json is a real file that Claude Code rewrites (the ecomono
  # flake seeds it once and does not manage it), so the two hooks go in by jq at
  # activation, the way ecomonoOmpMcp edits omp's mcp.json. Assigning both event
  # keys keeps the edit idempotent. Ceiling: it replaces any other Stop or
  # Notification hook; none exist today, so switch to an upsert by command name if
  # ecomono ever ships one. A failure warns and never stops the switch.
  #
  # omp needs nothing here: completion.notify and ask.notify are on by default and
  # call notify-send themselves when the terminal has no notification protocol.
  home.activation.claudeNotifyHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claude_settings="$HOME/.claude/settings.json"
    if [ -f "$claude_settings" ]; then
      claude_tmp="$claude_settings.hm-tmp"
      if ${pkgs.jq}/bin/jq --arg cmd ${claudeNotify} '
           .hooks.Stop = [ { hooks: [ { type: "command", command: ($cmd + " stop"), async: true } ] } ]
           | .hooks.Notification = [ { matcher: "permission_prompt|elicitation_dialog",
               hooks: [ { type: "command", command: ($cmd + " notification"), async: true } ] } ]
         ' "$claude_settings" > "$claude_tmp" \
         && ${pkgs.coreutils}/bin/chmod --reference="$claude_settings" "$claude_tmp"; then
        run mv "$claude_tmp" "$claude_settings"
      else
        rm -f "$claude_tmp"
        echo "claude-notify: could not update $claude_settings; add the hooks by hand" >&2
      fi
    fi
  '';
}
