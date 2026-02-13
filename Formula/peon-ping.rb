class PeonPing < Formula
  desc "Sound effects and desktop notifications for AI coding agents"
  homepage "https://peonping.com"
  url "https://github.com/PeonPing/peon-ping/archive/refs/tags/v1.7.1.tar.gz"
  sha256 "777090cd4a87a82bb6f8eecc0f5ef9fa84e5f96cede479c08a323f6905891ef9"
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

    # Install skills
    (libexec/"skills/peon-ping-toggle").install "skills/peon-ping-toggle/SKILL.md"
    (libexec/"skills/peon-ping-config").install "skills/peon-ping-config/SKILL.md"

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
            echo "Auto-detects installed IDEs (Claude Code, OpenCode) and sets up"
            echo "peon-ping for each: registers hooks/plugins, downloads sound packs."
            echo ""
            echo "Options:"
            echo "  --all              Install all available packs"
            echo "  --packs=p1,p2,...  Install only specified packs"
            echo "  (default)          Install 10 curated English packs"
            echo ""
            echo "Supported IDEs:"
            echo "  Claude Code  (~/.claude/)"
            echo "  OpenCode     (~/.config/opencode/)"
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
      OPENCODE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

      HAS_CLAUDE=false
      HAS_OPENCODE=false
      [ -d "$CLAUDE_DIR" ] && HAS_CLAUDE=true
      [ -d "$OPENCODE_DIR" ] && HAS_OPENCODE=true

      if [ "$HAS_CLAUDE" = false ] && [ "$HAS_OPENCODE" = false ]; then
        echo "Error: No supported IDE found."
        echo ""
        echo "peon-ping supports:"
        echo "  Claude Code  — expected at $CLAUDE_DIR"
        echo "  OpenCode     — expected at $OPENCODE_DIR"
        echo ""
        echo "Install one of these IDEs first, then re-run peon-ping-setup."
        exit 1
      fi

      echo "=== peon-ping setup (brew) ==="
      echo ""
      echo "Detected IDEs:"
      [ "$HAS_CLAUDE" = true ] && echo "  [x] Claude Code ($CLAUDE_DIR)"
      [ "$HAS_CLAUDE" = false ] && echo "  [ ] Claude Code (not found)"
      [ "$HAS_OPENCODE" = true ] && echo "  [x] OpenCode ($OPENCODE_DIR)"
      [ "$HAS_OPENCODE" = false ] && echo "  [ ] OpenCode (not found)"
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

      # Download packs to shared CESP path
      for pack in $PACKS; do
        mkdir -p "$PACKS_DIR/$pack/sounds"
        SOURCE_REPO="" SOURCE_REF="" SOURCE_PATH=""
        if [ -n "$REGISTRY_JSON" ]; then
          eval "$(python3 -c "
      import json, sys
      data = json.loads(sys.stdin.read())
      for p in data.get('packs', []):
          if p['name'] == '$pack':
              print(f\\"SOURCE_REPO='{p.get('source_repo', '')}'\\" )
              print(f\\"SOURCE_REF='{p.get('source_ref', 'main')}'\\" )
              print(f\\"SOURCE_PATH='{p.get('source_path', '')}'\\" )
              break
      " <<< "$REGISTRY_JSON")"
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
          if ! curl -fsSL "$PACK_BASE/sounds/$sfile" -o "$PACKS_DIR/$pack/sounds/$sfile" </dev/null 2>/dev/null; then
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
        SKILL_DIR="$CLAUDE_DIR/skills/peon-ping-toggle"
        mkdir -p "$SKILL_DIR"
        ln -sf "$LIBEXEC/skills/peon-ping-toggle/SKILL.md" "$SKILL_DIR/SKILL.md"
        CONFIG_SKILL_DIR="$CLAUDE_DIR/skills/peon-ping-config"
        mkdir -p "$CONFIG_SKILL_DIR"
        ln -sf "$LIBEXEC/skills/peon-ping-config/SKILL.md" "$CONFIG_SKILL_DIR/SKILL.md"

        # Register hooks
        echo "Registering Claude Code hooks..."
        python3 -c "
      import json, os
      settings_path = '$SETTINGS'
      hook_cmd = '$INSTALL_DIR/peon.sh'
      if os.path.exists(settings_path):
          with open(settings_path) as f:
              settings = json.load(f)
      else:
          settings = {}
      hooks = settings.setdefault('hooks', {})
      peon_hook = {'type': 'command', 'command': hook_cmd, 'timeout': 10}
      peon_entry = {'matcher': '', 'hooks': [peon_hook]}
      events = ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification', 'PermissionRequest']
      for event in events:
          event_hooks = hooks.get(event, [])
          event_hooks = [h for h in event_hooks if not any('notify.sh' in hk.get('command', '') or 'peon.sh' in hk.get('command', '') for hk in h.get('hooks', []))]
          event_hooks.append(peon_entry)
          hooks[event] = event_hooks
      settings['hooks'] = hooks
      with open(settings_path, 'w') as f:
          json.dump(settings, f, indent=2)
          f.write('\\n')
      print('Hooks registered for: ' + ', '.join(events))
      "

        # Initialize state
        if [ "$CLAUDE_UPDATING" = false ]; then
          echo '{}' > "$INSTALL_DIR/.state.json"
        fi

        echo "Claude Code setup complete."
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
      # Phase 6: Summary
      # -----------------------------------------------------------------------
      echo ""
      echo "=== Setup complete! ==="
      echo ""
      echo "Packs: $PACKS_DIR"
      echo ""
      if [ "$HAS_CLAUDE" = true ]; then
        echo "Claude Code:"
        echo "  Config:  $CLAUDE_DIR/hooks/peon-ping/config.json"
        echo "  Controls:"
        echo "    /peon-ping-toggle  — toggle sounds in Claude Code"
        echo "    peon toggle        — toggle from any terminal"
        echo "    peon status        — check current status"
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
      echo "Ready to work!"
    EOS
  end

  def caveats
    <<~EOS
      To complete setup, run:
        peon-ping-setup

      This auto-detects installed IDEs (Claude Code, OpenCode) and sets
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
