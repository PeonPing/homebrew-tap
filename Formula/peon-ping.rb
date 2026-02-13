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

    # Create setup script that registers hooks and downloads packs
    (bin/"peon-ping-setup").write <<~EOS
      #!/bin/bash
      # peon-ping setup — registers Claude Code hooks and downloads sound packs
      set -euo pipefail

      INSTALL_ALL=false
      CUSTOM_PACKS=""
      for arg in "$@"; do
        case "$arg" in
          --all) INSTALL_ALL=true ;;
          --packs=*) CUSTOM_PACKS="${arg#--packs=}" ;;
          --help|-h)
            echo "Usage: peon-ping-setup [--all] [--packs=pack1,pack2,...]"
            echo ""
            echo "Sets up peon-ping for Claude Code: registers hooks, downloads sound packs."
            echo ""
            echo "Options:"
            echo "  --all              Install all available packs"
            echo "  --packs=p1,p2,...  Install only specified packs"
            echo "  (default)          Install 10 curated English packs"
            exit 0
            ;;
        esac
      done

      LIBEXEC="#{libexec}"
      BASE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
      INSTALL_DIR="$BASE_DIR/hooks/peon-ping"
      SETTINGS="$BASE_DIR/settings.json"
      REGISTRY_URL="https://peonping.github.io/registry/index.json"

      DEFAULT_PACKS="peon peasant glados sc_kerrigan sc_battlecruiser ra2_kirov dota2_axe duke_nukem tf2_engineer hd2_helldiver"
      FALLBACK_PACKS="acolyte_de acolyte_ru aoe2 aom_greek brewmaster_ru dota2_axe duke_nukem glados hd2_helldiver molag_bal murloc ocarina_of_time peon peon_cz peon_de peon_es peon_fr peon_pl peon_ru peasant peasant_cz peasant_es peasant_fr peasant_ru ra2_kirov ra2_soviet_engineer ra_soviet rick sc_battlecruiser sc_firebat sc_kerrigan sc_medic sc_scv sc_tank sc_terran sc_vessel sheogorath sopranos tf2_engineer wc2_peasant"
      FALLBACK_REPO="PeonPing/og-packs"
      FALLBACK_REF="v1.1.0"

      if [ ! -d "$BASE_DIR" ]; then
        echo "Error: $BASE_DIR not found. Is Claude Code installed?"
        exit 1
      fi

      # Detect update vs fresh install
      UPDATING=false
      if [ -f "$INSTALL_DIR/peon.sh" ]; then
        UPDATING=true
        echo "=== peon-ping updater (brew) ==="
        echo ""
        echo "Existing install found. Updating..."
      else
        echo "=== peon-ping setup (brew) ==="
        echo ""
      fi

      # Link core files from Homebrew to Claude config
      mkdir -p "$INSTALL_DIR"
      ln -sf "$LIBEXEC/peon.sh" "$INSTALL_DIR/peon.sh"
      ln -sf "$LIBEXEC/VERSION" "$INSTALL_DIR/VERSION"
      ln -sf "$LIBEXEC/uninstall.sh" "$INSTALL_DIR/uninstall.sh"
      ln -sf "$LIBEXEC/completions.bash" "$INSTALL_DIR/completions.bash"
      ln -sf "$LIBEXEC/completions.fish" "$INSTALL_DIR/completions.fish"
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
      if [ "$UPDATING" = false ]; then
        cp "$LIBEXEC/config.json" "$INSTALL_DIR/config.json"
      fi

      # Install skills
      SKILL_DIR="$BASE_DIR/skills/peon-ping-toggle"
      mkdir -p "$SKILL_DIR"
      ln -sf "$LIBEXEC/skills/peon-ping-toggle/SKILL.md" "$SKILL_DIR/SKILL.md"
      CONFIG_SKILL_DIR="$BASE_DIR/skills/peon-ping-config"
      mkdir -p "$CONFIG_SKILL_DIR"
      ln -sf "$LIBEXEC/skills/peon-ping-config/SKILL.md" "$CONFIG_SKILL_DIR/SKILL.md"

      # Fetch pack list from registry
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

      # Download sound packs
      for pack in $PACKS; do
        mkdir -p "$INSTALL_DIR/packs/$pack/sounds"
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
        if ! curl -fsSL "$PACK_BASE/openpeon.json" -o "$INSTALL_DIR/packs/$pack/openpeon.json" 2>/dev/null; then
          echo "  Warning: failed to download manifest for $pack" >&2
          continue
        fi
        manifest="$INSTALL_DIR/packs/$pack/openpeon.json"
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
          if ! curl -fsSL "$PACK_BASE/sounds/$sfile" -o "$INSTALL_DIR/packs/$pack/sounds/$sfile" </dev/null 2>/dev/null; then
            echo "  Warning: failed to download $pack/sounds/$sfile" >&2
          fi
        done
      done

      # Verify sounds
      echo ""
      for pack in $PACKS; do
        sound_dir="$INSTALL_DIR/packs/$pack/sounds"
        sound_count=$({ ls "$sound_dir"/*.wav "$sound_dir"/*.mp3 "$sound_dir"/*.ogg 2>/dev/null || true; } | wc -l | tr -d ' ')
        if [ "$sound_count" -eq 0 ]; then
          echo "[$pack] Warning: No sound files found!"
        else
          echo "[$pack] $sound_count sound files installed."
        fi
      done

      # Register hooks
      echo ""
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
      if [ "$UPDATING" = false ]; then
        echo '{}' > "$INSTALL_DIR/.state.json"
      fi

      echo ""
      echo "=== Setup complete! ==="
      echo ""
      echo "Config: $INSTALL_DIR/config.json"
      echo ""
      echo "Quick controls:"
      echo "  /peon-ping-toggle  — toggle sounds in Claude Code"
      echo "  peon toggle        — toggle sounds from any terminal"
      echo "  peon status        — check if sounds are paused"
      echo ""
      echo "Ready to work!"
    EOS
  end

  def caveats
    <<~EOS
      To complete setup, run:
        peon-ping-setup

      This registers Claude Code hooks and downloads sound packs.

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
