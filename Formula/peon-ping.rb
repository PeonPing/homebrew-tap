class PeonPing < Formula
  desc "Sound effects and desktop notifications for AI coding agents"
  homepage "https://peonping.com"
  url "https://github.com/PeonPing/peon-ping/archive/refs/tags/v2.3.0.tar.gz"
  sha256 "164d360d4019fbe992562e3f92a7a1e0910059183a5cb1cdc0e710a8d48a0742"
  license "MIT"

  depends_on "python@3"

  def install
    # Install core files
    libexec.install "peon.sh"
    libexec.install "config.json"
    libexec.install "VERSION"
    libexec.install "uninstall.sh"
    libexec.install "install.sh"
    libexec.install "completions.bash"
    libexec.install "completions.fish"

    # Install relay server (devcontainer audio support)
    libexec.install "relay.sh" if (buildpath/"relay.sh").exist?

    # Install adapters
    (libexec/"adapters").install Dir["adapters/*.sh"]
    if (buildpath/"adapters/opencode").exist?
      (libexec/"adapters/opencode").install Dir["adapters/opencode/*"]
    end

    # Install scripts (pack downloader, peon-play Swift source, etc.)
    if (buildpath/"scripts").exist?
      (libexec/"scripts").install Dir["scripts/*.sh"]
      (libexec/"scripts").install Dir["scripts/*.ps1"] if Dir["scripts/*.ps1"].any?
      (libexec/"scripts").install Dir["scripts/*.js"]  if Dir["scripts/*.js"].any?
      (libexec/"scripts").install Dir["scripts/*.swift"] if Dir["scripts/*.swift"].any?
    end

    # Install MCP server
    if (buildpath/"mcp").exist?
      (libexec/"mcp").install Dir["mcp/*"]
    end

    # Install skills
    (libexec/"skills/peon-ping-toggle").install "skills/peon-ping-toggle/SKILL.md"
    (libexec/"skills/peon-ping-config").install "skills/peon-ping-config/SKILL.md"
    (libexec/"skills/peon-ping-use").install "skills/peon-ping-use/SKILL.md" if (buildpath/"skills/peon-ping-use/SKILL.md").exist?
    (libexec/"skills/peon-ping-log").install "skills/peon-ping-log/SKILL.md" if (buildpath/"skills/peon-ping-log/SKILL.md").exist?

    # Install trainer voice packs
    if (buildpath/"trainer").exist?
      (libexec/"trainer").install "trainer/manifest.json"
      (buildpath/"trainer/sounds").each_child do |subdir|
        next unless subdir.directory?
        (libexec/"trainer/sounds"/subdir.basename).install Dir[subdir/"*.mp3"]
      end
    end

    # Install icon
    (libexec/"docs").install "docs/peon-icon.png" if (buildpath/"docs/peon-icon.png").exist?

    # Create wrapper script that delegates to peon.sh
    (bin/"peon").write <<~EOS
      #!/bin/bash
      exec bash "#{libexec}/peon.sh" "$@"
    EOS

    # Create setup script that auto-detects IDEs and sets up accordingly
    (bin/"peon-ping-setup").write <<~EOS
      #!/bin/bash
      # peon-ping setup — auto-detects IDEs and sets up hooks/plugins + sound packs
      set -euo pipefail

      # -----------------------------------------------------------------------
      # Phase 1: Parse arguments
      # -----------------------------------------------------------------------
      INSTALL_ALL=false
      CUSTOM_PACKS=""
      for arg in "$@"; do
        case "$arg" in
          --all) INSTALL_ALL=true ;;
          --packs=*) CUSTOM_PACKS="${arg#--packs=}" ;;
          --help|-h)
            echo "Usage: peon-ping-setup [--all] [--packs=pack1,pack2,...]"
            echo ""
            echo "Auto-detects installed IDEs (Claude Code, Cursor, OpenCode, Windsurf) and sets up"
            echo "peon-ping for each: registers hooks/plugins, downloads sound packs."
            echo ""
            echo "Options:"
            echo "  --all              Install all available packs"
            echo "  --packs=p1,p2,...  Install only specified packs"
            echo "  (default)          Install 10 curated English packs"
            echo ""
            echo "Auto-detected IDEs (hooks registered automatically):"
            echo "  Claude Code  (~/.claude/)"
            echo "  Cursor       (~/.cursor/)"
            echo "  OpenCode     (~/.config/opencode/)"
            echo "  Windsurf     (~/.codeium/windsurf/)"
            echo ""
            echo "More IDEs supported via adapters (see peonping.com for setup):"
            echo "  Kilo CLI, Kiro, Codex, Google Antigravity, OpenClaw"
            exit 0
            ;;
        esac
      done

      # Use the stable opt path so symlinks survive brew upgrades.
      LIBEXEC="$(brew --prefix peon-ping)/libexec"
      REGISTRY_URL="https://peonping.github.io/registry/index.json"
      PACKS_DIR="$HOME/.openpeon/packs"

      DEFAULT_PACKS="peon peasant glados sc_kerrigan sc_battlecruiser ra2_kirov dota2_axe duke_nukem tf2_engineer hd2_helldiver"
      FALLBACK_PACKS="acolyte_de acolyte_ru aoe2 aom_greek brewmaster_ru dota2_axe duke_nukem glados hd2_helldiver molag_bal murloc ocarina_of_time peon peon_cz peon_de peon_es peon_fr peon_pl peon_ru peasant peasant_cz peasant_es peasant_fr peasant_ru ra2_kirov ra2_soviet_engineer ra_soviet rick sc_battlecruiser sc_firebat sc_kerrigan sc_medic sc_scv sc_tank sc_terran sc_vessel sheogorath sopranos tf2_engineer wc2_peasant"
      FALLBACK_REPO="PeonPing/og-packs"
      FALLBACK_REF="v1.1.0"

      # -----------------------------------------------------------------------
      # Phase 2: Auto-detect installed IDEs
      # -----------------------------------------------------------------------
      CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
      CURSOR_DIR="$HOME/.cursor"
      OPENCODE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
      WINDSURF_DIR="$HOME/.codeium/windsurf"

      HAS_CLAUDE=false
      HAS_CURSOR=false
      HAS_OPENCODE=false
      HAS_WINDSURF=false
      [ -d "$CLAUDE_DIR" ]   && HAS_CLAUDE=true
      [ -d "$CURSOR_DIR" ]   && HAS_CURSOR=true
      [ -d "$OPENCODE_DIR" ] && HAS_OPENCODE=true
      [ -d "$WINDSURF_DIR" ] && HAS_WINDSURF=true

      if [ "$HAS_CLAUDE" = false ] && [ "$HAS_CURSOR" = false ] && \
         [ "$HAS_OPENCODE" = false ] && [ "$HAS_WINDSURF" = false ]; then
        echo "Error: No supported IDE found."
        echo ""
        echo "peon-ping supports:"
        echo "  Claude Code  — expected at $CLAUDE_DIR"
        echo "  Cursor       — expected at $CURSOR_DIR"
        echo "  OpenCode     — expected at $OPENCODE_DIR"
        echo "  Windsurf     — expected at $WINDSURF_DIR"
        echo ""
        echo "Install one of these IDEs first, then re-run peon-ping-setup."
        exit 1
      fi

      echo "=== peon-ping setup (brew) ==="
      echo ""
      echo "Detected IDEs:"
      [ "$HAS_CLAUDE" = true ]   && echo "  [x] Claude Code ($CLAUDE_DIR)"
      [ "$HAS_CLAUDE" = false ]  && echo "  [ ] Claude Code (not found)"
      [ "$HAS_CURSOR" = true ]   && echo "  [x] Cursor ($CURSOR_DIR)"
      [ "$HAS_CURSOR" = false ]  && echo "  [ ] Cursor (not found)"
      [ "$HAS_OPENCODE" = true ]  && echo "  [x] OpenCode ($OPENCODE_DIR)"
      [ "$HAS_OPENCODE" = false ] && echo "  [ ] OpenCode (not found)"
      [ "$HAS_WINDSURF" = true ]  && echo "  [x] Windsurf ($WINDSURF_DIR)"
      [ "$HAS_WINDSURF" = false ] && echo "  [ ] Windsurf (not found)"
      echo ""

      # -----------------------------------------------------------------------
      # Phase 3: Download sound packs to shared CESP path (~/.openpeon/packs/)
      # -----------------------------------------------------------------------
      PACKS=""
      ALL_PACKS=""
      REGISTRY_JSON=""
      echo "Fetching pack registry..."
      if REGISTRY_JSON=$(curl -fsSL "$REGISTRY_URL" 2>/dev/null); then
        ALL_PACKS=$(python3 -c "
      import json, sys
      data = json.loads(sys.stdin.read())
      for p in data.get('packs', []):
          print(p['name'])
      " <<< "$REGISTRY_JSON")
        TOTAL_AVAILABLE=$(echo "$ALL_PACKS" | wc -l | tr -d ' ')
        echo "Registry: $TOTAL_AVAILABLE packs available"
      else
        echo "Warning: Could not fetch registry, using fallback pack list"
        ALL_PACKS="$FALLBACK_PACKS"
      fi

      # Select packs to install
      if [ -n "$CUSTOM_PACKS" ]; then
        PACKS=$(echo "$CUSTOM_PACKS" | tr ',' ' ')
        echo "Installing custom packs: $PACKS"
      elif [ "$INSTALL_ALL" = true ]; then
        PACKS="$ALL_PACKS"
        echo "Installing all $(echo "$PACKS" | wc -l | tr -d ' ') packs..."
      else
        PACKS="$DEFAULT_PACKS"
        echo "Installing $(echo "$PACKS" | wc -w | tr -d ' ') default packs (use --all for all $(echo "$ALL_PACKS" | wc -l | tr -d ' '))"
      fi

      # URL-encode characters that break raw GitHub URLs (e.g. ? in filenames)
      urlencode_filename() {
        local f="$1"
        f="${f//\\?/%3F}"
        f="${f//\\!/%21}"
        f="${f//\\#/%23}"
        printf '%s' "$f"
      }

      # Compute sha256 of a file (portable across macOS and Linux)
      file_sha256() {
        if command -v shasum &>/dev/null; then
          shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
        elif command -v sha256sum &>/dev/null; then
          sha256sum "$1" 2>/dev/null | cut -d' ' -f1
        else
          python3 -c "import hashlib; print(hashlib.sha256(open('$1','rb').read()).hexdigest())" 2>/dev/null
        fi
      }

      # Check if a downloaded sound file matches its stored checksum
      is_cached_valid() {
        local filepath="$1" checksums_file="$2" filename="$3"
        [ -s "$filepath" ] || return 1
        [ -f "$checksums_file" ] || return 1
        local stored_hash current_hash
        stored_hash=$(grep "^$filename " "$checksums_file" 2>/dev/null | cut -d' ' -f2)
        [ -n "$stored_hash" ] || return 1
        current_hash=$(file_sha256 "$filepath")
        [ "$stored_hash" = "$current_hash" ]
      }

      # Store checksum for a downloaded file
      store_checksum() {
        local checksums_file="$1" filename="$2" filepath="$3"
        local hash
        hash=$(file_sha256 "$filepath")
        grep -v "^$filename " "$checksums_file" > "$checksums_file.tmp" 2>/dev/null || true
        echo "$filename $hash" >> "$checksums_file.tmp"
        mv "$checksums_file.tmp" "$checksums_file"
      }

      # Download packs to shared CESP path
      # Security: read registry fields without eval to prevent code injection if registry is compromised/MITM'd
      for pack in $PACKS; do
        mkdir -p "$PACKS_DIR/$pack/sounds"
        SOURCE_REPO="" SOURCE_REF="" SOURCE_PATH=""
        if [ -n "$REGISTRY_JSON" ]; then
          IFS=$'\\t' read -r SOURCE_REPO SOURCE_REF SOURCE_PATH <<< "$(python3 -c "
      import json, sys, re
      pack_name = sys.argv[1]
      data = json.loads(sys.stdin.read())
      for p in data.get('packs', []):
          if p.get('name') == pack_name:
              repo = p.get('source_repo', '') or ''
              ref = p.get('source_ref', 'main') or 'main'
              path = p.get('source_path', '') or ''
              # Allow only safe chars for URL path components (no shell metacharacters)
              repo = re.sub(r'[^a-zA-Z0-9_./-]', '', repo)
              ref = re.sub(r'[^a-zA-Z0-9_.-]', '', ref)
              path = re.sub(r'[^a-zA-Z0-9_./-]', '', path)
              print(repo, ref, path, sep='\\t')
              break
      else:
          print('', 'main', '', sep='\\t')
      " "$pack" <<< "$REGISTRY_JSON")"
        fi
        if [ -z "$SOURCE_REPO" ]; then
          SOURCE_REPO="$FALLBACK_REPO"
          SOURCE_REF="$FALLBACK_REF"
          SOURCE_PATH="$pack"
        fi
        if [ -n "$SOURCE_PATH" ]; then
          PACK_BASE="https://raw.githubusercontent.com/$SOURCE_REPO/$SOURCE_REF/$SOURCE_PATH"
        else
          PACK_BASE="https://raw.githubusercontent.com/$SOURCE_REPO/$SOURCE_REF"
        fi
        if ! curl -fsSL "$PACK_BASE/openpeon.json" -o "$PACKS_DIR/$pack/openpeon.json" 2>/dev/null; then
          echo "  Warning: failed to download manifest for $pack" >&2
          continue
        fi
        manifest="$PACKS_DIR/$pack/openpeon.json"
        CHECKSUMS_FILE="$PACKS_DIR/$pack/.checksums"
        touch "$CHECKSUMS_FILE"
        python3 -c "
      import json, os
      m = json.load(open('$manifest'))
      seen = set()
      for cat in m.get('categories', {}).values():
          for s in cat.get('sounds', []):
              f = s['file']
              basename = os.path.basename(f)
              if basename not in seen:
                  seen.add(basename)
                  print(basename)
      " | while read -r sfile; do
          if is_cached_valid "$PACKS_DIR/$pack/sounds/$sfile" "$CHECKSUMS_FILE" "$sfile"; then
            : # already downloaded and checksum matches
          elif curl -fsSL "$PACK_BASE/sounds/$(urlencode_filename "$sfile")" -o "$PACKS_DIR/$pack/sounds/$sfile" </dev/null 2>/dev/null; then
            store_checksum "$CHECKSUMS_FILE" "$sfile" "$PACKS_DIR/$pack/sounds/$sfile"
          else
            echo "  Warning: failed to download $pack/sounds/$sfile" >&2
          fi
        done
      done

      # Verify sounds
      echo ""
      for pack in $PACKS; do
        sound_dir="$PACKS_DIR/$pack/sounds"
        sound_count=$({ ls "$sound_dir"/*.wav "$sound_dir"/*.mp3 "$sound_dir"/*.ogg 2>/dev/null || true; } | wc -l | tr -d ' ')
        if [ "$sound_count" -eq 0 ]; then
          echo "[$pack] Warning: No sound files found!"
        else
          echo "[$pack] $sound_count sound files installed."
        fi
      done

      # -----------------------------------------------------------------------
      # Phase 4: Claude Code setup
      # -----------------------------------------------------------------------
      if [ "$HAS_CLAUDE" = true ]; then
        echo ""
        echo "--- Setting up Claude Code ---"
        INSTALL_DIR="$CLAUDE_DIR/hooks/peon-ping"
        SETTINGS="$CLAUDE_DIR/settings.json"

        # Detect update vs fresh install
        CLAUDE_UPDATING=false
        if [ -f "$INSTALL_DIR/peon.sh" ]; then
          CLAUDE_UPDATING=true
          echo "Existing Claude Code install found. Updating..."
        fi

        # Link core files from Homebrew to Claude config
        mkdir -p "$INSTALL_DIR"
        ln -sf "$LIBEXEC/peon.sh" "$INSTALL_DIR/peon.sh"
        ln -sf "$LIBEXEC/VERSION" "$INSTALL_DIR/VERSION"
        ln -sf "$LIBEXEC/uninstall.sh" "$INSTALL_DIR/uninstall.sh"
        ln -sf "$LIBEXEC/completions.bash" "$INSTALL_DIR/completions.bash"
        ln -sf "$LIBEXEC/completions.fish" "$INSTALL_DIR/completions.fish"
        # Link relay server if available
        [ -f "$LIBEXEC/relay.sh" ] && ln -sf "$LIBEXEC/relay.sh" "$INSTALL_DIR/relay.sh"
        mkdir -p "$INSTALL_DIR/adapters"
        for f in "$LIBEXEC/adapters/"*.sh; do
          [ -f "$f" ] && ln -sf "$f" "$INSTALL_DIR/adapters/"
        done
        if [ -d "$LIBEXEC/adapters/opencode" ]; then
          mkdir -p "$INSTALL_DIR/adapters/opencode"
          for f in "$LIBEXEC/adapters/opencode/"*; do
            [ -f "$f" ] && ln -sf "$f" "$INSTALL_DIR/adapters/opencode/"
          done
        fi
        # Link scripts (pack-download.sh, mac-overlay.js, peon-play.swift, etc.)
        if [ -d "$LIBEXEC/scripts" ]; then
          mkdir -p "$INSTALL_DIR/scripts"
          for f in "$LIBEXEC/scripts/"*; do
            [ -f "$f" ] && ln -sf "$f" "$INSTALL_DIR/scripts/"
          done
          chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true
        fi
        # Link MCP server
        if [ -d "$LIBEXEC/mcp" ]; then
          mkdir -p "$INSTALL_DIR/mcp"
          for f in "$LIBEXEC/mcp/"*; do
            [ -f "$f" ] && ln -sf "$f" "$INSTALL_DIR/mcp/"
          done
        fi
        if [ -f "$LIBEXEC/docs/peon-icon.png" ]; then
          mkdir -p "$INSTALL_DIR/docs"
          ln -sf "$LIBEXEC/docs/peon-icon.png" "$INSTALL_DIR/docs/"
        fi
        if [ "$CLAUDE_UPDATING" = false ]; then
          cp "$LIBEXEC/config.json" "$INSTALL_DIR/config.json"
        fi

        # Symlink packs from shared CESP path
        # Remove existing packs dir if it's a regular directory (migrate to symlink)
        if [ -d "$INSTALL_DIR/packs" ] && [ ! -L "$INSTALL_DIR/packs" ]; then
          echo "Migrating Claude Code packs to shared location..."
          # Move any existing packs that aren't in the shared dir yet
          mkdir -p "$PACKS_DIR"
          for existing_pack in "$INSTALL_DIR/packs/"*/; do
            pack_name=$(basename "$existing_pack")
            if [ "$pack_name" != "*" ] && [ ! -d "$PACKS_DIR/$pack_name" ]; then
              mv "$existing_pack" "$PACKS_DIR/"
            fi
          done
          rm -r "$INSTALL_DIR/packs"
        fi
        ln -sfn "$PACKS_DIR" "$INSTALL_DIR/packs"

        # Install skills
        for skill_name in peon-ping-toggle peon-ping-config peon-ping-use peon-ping-log; do
          SKILL_SRC="$LIBEXEC/skills/$skill_name/SKILL.md"
          if [ -f "$SKILL_SRC" ]; then
            SKILL_TARGET="$CLAUDE_DIR/skills/$skill_name"
            mkdir -p "$SKILL_TARGET"
            ln -sf "$SKILL_SRC" "$SKILL_TARGET/SKILL.md"
          fi
        done

        # Install trainer voice packs
        if [ -d "$LIBEXEC/trainer" ]; then
          TRAINER_DIR="$INSTALL_DIR/trainer"
          mkdir -p "$TRAINER_DIR/sounds"
          ln -sf "$LIBEXEC/trainer/manifest.json" "$TRAINER_DIR/manifest.json"
          for subdir in "$LIBEXEC/trainer/sounds/"*/; do
            [ -d "$subdir" ] || continue
            dirname=$(basename "$subdir")
            mkdir -p "$TRAINER_DIR/sounds/$dirname"
            for f in "$subdir"*.mp3; do
              [ -f "$f" ] && ln -sf "$f" "$TRAINER_DIR/sounds/$dirname/"
            done
          done
        fi

        # Build peon-play (Sound Effects device routing for macOS)
        if command -v swiftc &>/dev/null; then
          SWIFT_SRC="$LIBEXEC/scripts/peon-play.swift"
          PEON_PLAY="$INSTALL_DIR/scripts/peon-play"
          if [ -f "$SWIFT_SRC" ] && [ ! -x "$PEON_PLAY" ]; then
            echo "Building peon-play (Sound Effects device support)..."
            swiftc -O -o "$PEON_PLAY" "$SWIFT_SRC" \
              -framework AVFoundation -framework CoreAudio -framework AudioToolbox 2>/dev/null \
              && echo "  peon-play built successfully" \
              || echo "  Warning: could not build peon-play, using afplay fallback"
          fi
        fi

        # Register Claude Code hooks
        echo "Registering Claude Code hooks..."
        python3 -c "
      import json, os, sys
      settings_path = '$SETTINGS'
      hook_cmd = '$INSTALL_DIR/peon.sh'
      if os.path.exists(settings_path):
          with open(settings_path) as f:
              try:
                  settings = json.load(f)
              except Exception:
                  settings = {}
      else:
          settings = {}
      hooks = settings.setdefault('hooks', {})
      peon_hook_sync  = {'type': 'command', 'command': hook_cmd, 'timeout': 10}
      peon_hook_async = {'type': 'command', 'command': hook_cmd, 'timeout': 10, 'async': True}
      sync_events = ('SessionStart',)
      bash_only   = ('PostToolUseFailure',)
      events = ['SessionStart', 'SessionEnd', 'SubagentStart', 'UserPromptSubmit',
                'Stop', 'Notification', 'PermissionRequest', 'PostToolUseFailure', 'PreCompact']
      for event in events:
          hook = peon_hook_sync if event in sync_events else peon_hook_async
          if event in bash_only:
              peon_entry = {'matcher': 'Bash', 'hooks': [hook]}
          else:
              peon_entry = {'matcher': '', 'hooks': [hook]}
          event_hooks = hooks.get(event, [])
          event_hooks = [
              h for h in event_hooks
              if not any('peon.sh' in hk.get('command', '') or 'notify.sh' in hk.get('command', '')
                         for hk in h.get('hooks', []))
          ]
          event_hooks.append(peon_entry)
          hooks[event] = event_hooks
      settings['hooks'] = hooks
      with open(settings_path, 'w') as f:
          json.dump(settings, f, indent=2)
          f.write('\\n')
      print('Hooks registered for: ' + ', '.join(events))
      "

        # Register Cursor hooks when both Claude Code and Cursor are installed
        if [ "$HAS_CURSOR" = true ]; then
          CURSOR_SETTINGS="$CURSOR_DIR/settings.json"
          echo "Registering Cursor hooks..."
          python3 -c "
      import json, os
      settings_path = '$CURSOR_SETTINGS'
      hook_cmd = '$INSTALL_DIR/peon.sh'
      if os.path.exists(settings_path):
          with open(settings_path) as f:
              try:
                  settings = json.load(f)
              except Exception:
                  settings = {}
      else:
          settings = {}
      hooks = settings.setdefault('hooks', {})
      peon_hook = {'type': 'command', 'command': hook_cmd, 'timeout': 10, 'async': True}
      peon_entry = {'matcher': '', 'hooks': [peon_hook]}
      event_hooks = hooks.get('beforeSubmitPrompt', [])
      event_hooks = [h for h in event_hooks
                     if not any('peon.sh' in hk.get('command', '') for hk in h.get('hooks', []))]
      event_hooks.append(peon_entry)
      hooks['beforeSubmitPrompt'] = event_hooks
      settings['hooks'] = hooks
      with open(settings_path, 'w') as f:
          json.dump(settings, f, indent=2)
          f.write('\\n')
      print('Cursor beforeSubmitPrompt hook registered')
      "
        fi

        # Initialize state
        if [ "$CLAUDE_UPDATING" = false ]; then
          echo '{}' > "$INSTALL_DIR/.state.json"
        fi

        echo "Claude Code setup complete."
      fi

      # -----------------------------------------------------------------------
      # Phase 4b: Cursor-only setup (no Claude Code)
      # -----------------------------------------------------------------------
      if [ "$HAS_CURSOR" = true ] && [ "$HAS_CLAUDE" = false ]; then
        echo ""
        echo "--- Setting up Cursor (standalone) ---"
        # Install to ~/.claude/hooks/peon-ping so peon.sh has a stable home
        INSTALL_DIR="$HOME/.claude/hooks/peon-ping"
        CURSOR_SETTINGS="$CURSOR_DIR/settings.json"

        mkdir -p "$INSTALL_DIR"
        ln -sf "$LIBEXEC/peon.sh"      "$INSTALL_DIR/peon.sh"
        ln -sf "$LIBEXEC/VERSION"      "$INSTALL_DIR/VERSION"
        ln -sf "$LIBEXEC/uninstall.sh" "$INSTALL_DIR/uninstall.sh"
        [ -f "$LIBEXEC/relay.sh" ] && ln -sf "$LIBEXEC/relay.sh" "$INSTALL_DIR/relay.sh"
        mkdir -p "$INSTALL_DIR/adapters"
        for f in "$LIBEXEC/adapters/"*.sh; do
          [ -f "$f" ] && ln -sf "$f" "$INSTALL_DIR/adapters/"
        done
        if [ -d "$LIBEXEC/scripts" ]; then
          mkdir -p "$INSTALL_DIR/scripts"
          for f in "$LIBEXEC/scripts/"*; do
            [ -f "$f" ] && ln -sf "$f" "$INSTALL_DIR/scripts/"
          done
          chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true
        fi
        if [ -f "$LIBEXEC/docs/peon-icon.png" ]; then
          mkdir -p "$INSTALL_DIR/docs"
          ln -sf "$LIBEXEC/docs/peon-icon.png" "$INSTALL_DIR/docs/"
        fi
        [ -f "$INSTALL_DIR/config.json" ] || cp "$LIBEXEC/config.json" "$INSTALL_DIR/config.json"
        ln -sfn "$PACKS_DIR" "$INSTALL_DIR/packs"

        echo "Registering Cursor hooks..."
        python3 -c "
      import json, os
      settings_path = '$CURSOR_SETTINGS'
      hook_cmd = '$INSTALL_DIR/peon.sh'
      if os.path.exists(settings_path):
          with open(settings_path) as f:
              try:
                  settings = json.load(f)
              except Exception:
                  settings = {}
      else:
          settings = {}
      hooks = settings.setdefault('hooks', {})
      peon_hook = {'type': 'command', 'command': hook_cmd, 'timeout': 10, 'async': True}
      peon_entry = {'matcher': '', 'hooks': [peon_hook]}
      event_hooks = hooks.get('beforeSubmitPrompt', [])
      event_hooks = [h for h in event_hooks
                     if not any('peon.sh' in hk.get('command', '') for hk in h.get('hooks', []))]
      event_hooks.append(peon_entry)
      hooks['beforeSubmitPrompt'] = event_hooks
      settings['hooks'] = hooks
      with open(settings_path, 'w') as f:
          json.dump(settings, f, indent=2)
          f.write('\\n')
      print('Cursor beforeSubmitPrompt hook registered')
      "
        echo '{}' > "$INSTALL_DIR/.state.json" 2>/dev/null || true
        echo "Cursor standalone setup complete."
      fi

      # -----------------------------------------------------------------------
      # Phase 5: OpenCode setup
      # -----------------------------------------------------------------------
      if [ "$HAS_OPENCODE" = true ]; then
        echo ""
        echo "--- Setting up OpenCode ---"
        OPENCODE_PLUGINS_DIR="$OPENCODE_DIR/plugins"
        OPENCODE_PEON_DIR="$OPENCODE_DIR/peon-ping"

        # Check that the plugin source exists in libexec
        PLUGIN_SRC="$LIBEXEC/adapters/opencode/peon-ping.ts"
        if [ ! -f "$PLUGIN_SRC" ]; then
          echo "Warning: OpenCode plugin not found at $PLUGIN_SRC"
          echo "The Homebrew formula may need updating. Skipping OpenCode setup."
        else
          # Detect update vs fresh install
          OPENCODE_UPDATING=false
          if [ -f "$OPENCODE_PLUGINS_DIR/peon-ping.ts" ]; then
            OPENCODE_UPDATING=true
            echo "Existing OpenCode install found. Updating plugin..."
          fi

          # Symlink plugin to OpenCode plugins directory (so brew upgrade auto-updates)
          mkdir -p "$OPENCODE_PLUGINS_DIR"
          ln -sf "$PLUGIN_SRC" "$OPENCODE_PLUGINS_DIR/peon-ping.ts"
          echo "Plugin installed to $OPENCODE_PLUGINS_DIR/peon-ping.ts"

          # Create config (only on fresh install)
          mkdir -p "$OPENCODE_PEON_DIR"
          if [ "$OPENCODE_UPDATING" = false ] || [ ! -f "$OPENCODE_PEON_DIR/config.json" ]; then
            cat > "$OPENCODE_PEON_DIR/config.json" << 'CONFIGEOF'
      {
        "active_pack": "peon",
        "volume": 0.5,
        "enabled": true,
        "categories": {
          "session.start": true,
          "session.end": true,
          "task.acknowledge": true,
          "task.complete": true,
          "task.error": true,
          "task.progress": true,
          "input.required": true,
          "resource.limit": true,
          "user.spam": true
        },
        "spam_threshold": 3,
        "spam_window_seconds": 10,
        "pack_rotation": [],
        "debounce_ms": 500
      }
      CONFIGEOF
            echo "Config created at $OPENCODE_PEON_DIR/config.json"
          else
            echo "Config already exists, preserved."
          fi

          # Copy peon icon to plugin config dir (used by resolveIconPath())
          ICON_SRC="$LIBEXEC/docs/peon-icon.png"
          if [ -f "$ICON_SRC" ]; then
            cp "$ICON_SRC" "$OPENCODE_PEON_DIR/peon-icon.png"
          fi

          echo "OpenCode setup complete."
        fi
      fi

      # -----------------------------------------------------------------------
      # Phase 6: Windsurf setup
      # -----------------------------------------------------------------------
      if [ "$HAS_WINDSURF" = true ]; then
        echo ""
        echo "--- Setting up Windsurf ---"
        WINDSURF_HOOKS="$WINDSURF_DIR/hooks.json"

        # Windsurf adapter uses peon.sh from Claude install or standalone
        if [ "$HAS_CLAUDE" = true ]; then
          ADAPTER_PATH="$CLAUDE_DIR/hooks/peon-ping/adapters/windsurf.sh"
        else
          # Standalone Windsurf install: create minimal structure
          WINDSURF_PEON_DIR="$HOME/.claude/hooks/peon-ping"
          mkdir -p "$WINDSURF_PEON_DIR/adapters"
          ln -sf "$LIBEXEC/peon.sh" "$WINDSURF_PEON_DIR/peon.sh"
          ln -sf "$LIBEXEC/adapters/windsurf.sh" "$WINDSURF_PEON_DIR/adapters/windsurf.sh"
          ln -sfn "$PACKS_DIR" "$WINDSURF_PEON_DIR/packs"
          if [ ! -f "$WINDSURF_PEON_DIR/config.json" ]; then
            cp "$LIBEXEC/config.json" "$WINDSURF_PEON_DIR/config.json"
          fi
          ADAPTER_PATH="$WINDSURF_PEON_DIR/adapters/windsurf.sh"
        fi

        # Register hooks in hooks.json
        echo "Registering Windsurf hooks..."
        python3 -c "
      import json, os
      hooks_path = '$WINDSURF_HOOKS'
      adapter_path = '$ADAPTER_PATH'
      if os.path.exists(hooks_path):
          with open(hooks_path) as f:
              config = json.load(f)
      else:
          config = {}
      hooks = config.setdefault('hooks', {})
      events = {
          'post_cascade_response': 'post_cascade_response',
          'pre_user_prompt': 'pre_user_prompt',
          'post_write_code': 'post_write_code',
          'post_run_command': 'post_run_command'
      }
      for event, arg in events.items():
          hook_entry = {
              'command': f'bash {adapter_path} {arg}',
              'show_output': False
          }
          event_hooks = hooks.get(event, [])
          # Remove existing peon-ping entries
          event_hooks = [h for h in event_hooks if 'windsurf.sh' not in h.get('command', '')]
          event_hooks.append(hook_entry)
          hooks[event] = event_hooks
      config['hooks'] = hooks
      os.makedirs(os.path.dirname(hooks_path), exist_ok=True)
      with open(hooks_path, 'w') as f:
          json.dump(config, f, indent=2)
          f.write('\\n')
      print('Hooks registered for: ' + ', '.join(events.keys()))
      "

        echo "Windsurf setup complete."
      fi

      # -----------------------------------------------------------------------
      # Phase 7: Summary
      # -----------------------------------------------------------------------
      echo ""
      echo "=== Setup complete! ==="
      echo ""
      echo "Packs: $PACKS_DIR"
      echo ""
      if [ "$HAS_CLAUDE" = true ]; then
        echo "Claude Code:"
        echo "  Config:  $CLAUDE_DIR/hooks/peon-ping/config.json"
        echo "  Skills:  /peon-ping-toggle, /peon-ping-config, /peon-ping-use, /peon-ping-log"
        echo "  Controls:"
        echo "    /peon-ping-toggle  — toggle sounds in Claude Code"
        echo "    peon toggle        — toggle from any terminal"
        echo "    peon status        — check current status"
        echo ""
        echo "  MCP server (lets agent choose sounds):"
        echo "    node $CLAUDE_DIR/hooks/peon-ping/mcp/peon-mcp.js"
        echo "    Add to .mcp.json as stdio MCP server"
        echo ""
      fi
      if [ "$HAS_CURSOR" = true ]; then
        echo "Cursor: hooks registered via beforeSubmitPrompt"
        echo ""
      fi
      if [ "$HAS_OPENCODE" = true ]; then
        echo "OpenCode:"
        echo "  Plugin:  $OPENCODE_DIR/plugins/peon-ping.ts"
        echo "  Config:  $OPENCODE_DIR/peon-ping/config.json"
        echo ""
        echo "  For rich desktop notifications (title, subtitle, grouping):"
        echo "    brew install terminal-notifier"
        echo "  The plugin auto-detects it at runtime."
        echo ""
        if command -v terminal-notifier >/dev/null 2>&1; then
          echo "  Optional: replace terminal-notifier's default icon with the peon icon:"
          if [ -f "$LIBEXEC/adapters/opencode/setup-icon.sh" ]; then
            echo "    bash $LIBEXEC/adapters/opencode/setup-icon.sh"
          else
            echo "    bash <(curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode/setup-icon.sh)"
          fi
          echo ""
        fi
        echo "  Restart OpenCode to activate."
        echo ""
      fi
      if [ "$HAS_WINDSURF" = true ]; then
        echo "Windsurf:"
        echo "  Hooks:   $WINDSURF_DIR/hooks.json"
        if [ "$HAS_CLAUDE" = true ]; then
          echo "  Adapter: $CLAUDE_DIR/hooks/peon-ping/adapters/windsurf.sh"
          echo "  Config:  $CLAUDE_DIR/hooks/peon-ping/config.json"
        else
          echo "  Adapter: $HOME/.claude/hooks/peon-ping/adapters/windsurf.sh"
          echo "  Config:  $HOME/.claude/hooks/peon-ping/config.json"
        fi
        echo ""
        echo "  Restart Windsurf to activate."
        echo ""
      fi
      echo "Other IDEs (Kilo CLI, Kiro, Codex, Antigravity, OpenClaw): see https://peonping.com for adapter setup."
      echo ""
      echo "Ready to work!"
    EOS
  end

  def caveats
    <<~EOS
      To complete setup, run:
        peon-ping-setup

      Auto-detects installed IDEs (Claude Code, Cursor, OpenCode, Windsurf) and sets
      up hooks/plugins and downloads sound packs for each.

      Options:
        peon-ping-setup              Install 10 default packs
        peon-ping-setup --all        Install all packs
        peon-ping-setup --packs=peon,glados  Install specific packs

      After setup, use:
        peon toggle     Mute/unmute sounds
        peon status     Check current status
        peon help       See all commands
    EOS
  end

  test do
    assert_match "peon-ping", shell_output("#{bin}/peon help")
  end
end
