#!/bin/bash
# install.sh — Install Claude Memory Scaffold globally
#
# What it does:
#   1. Copies global CLAUDE.md to ~/.claude/ (backs up existing)
#   2. Merges hooks into ~/.claude/settings.json (backs up existing)
#   3. Copies templates + init script
#   4. Creates ~/bin/claude-init symlink
#
# Safe to re-run — backs up before overwriting.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/$(date +%Y%m%d-%H%M%S)"

echo "Claude Memory Scaffold — Installer"
echo "===================================="
echo ""

# --- Step 1: Global CLAUDE.md ---
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$CLAUDE_DIR/CLAUDE.md" "$BACKUP_DIR/CLAUDE.md"
    echo "  Backed up existing CLAUDE.md → $BACKUP_DIR/"
fi
cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo "  Installed ~/.claude/CLAUDE.md"

# --- Step 2: Hooks in settings.json ---
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$CLAUDE_DIR/settings.json" "$BACKUP_DIR/settings.json"
    echo "  Backed up existing settings.json → $BACKUP_DIR/"

    # Check if hooks already exist
    if python3 -c "import json; d=json.load(open('$CLAUDE_DIR/settings.json')); assert 'hooks' in d and 'PreCompact' in d['hooks']" 2>/dev/null; then
        echo "  Hooks already present in settings.json — skipped"
    else
        # Merge hooks into existing settings
        python3 -c "
import json
with open('$CLAUDE_DIR/settings.json') as f:
    existing = json.load(f)
with open('$SCRIPT_DIR/settings.json') as f:
    scaffold = json.load(f)
existing['hooks'] = scaffold.get('hooks', {})
with open('$CLAUDE_DIR/settings.json', 'w') as f:
    json.dump(existing, f, indent=2)
print('  Merged hooks into ~/.claude/settings.json')
"
    fi
else
    cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    echo "  Installed ~/.claude/settings.json"
fi

# --- Step 3: Templates ---
mkdir -p "$CLAUDE_DIR/templates"
cp -r "$SCRIPT_DIR/templates/"* "$CLAUDE_DIR/templates/"
cp "$SCRIPT_DIR/claude-init.sh" "$CLAUDE_DIR/templates/claude-init.sh"
chmod +x "$CLAUDE_DIR/templates/claude-init.sh"
echo "  Installed templates → ~/.claude/templates/"

# --- Step 3b: Memory-aware skills → ~/.claude/skills/ ---
if [ -d "$SCRIPT_DIR/templates/skills" ]; then
    mkdir -p "$CLAUDE_DIR/skills"
    for skill_dir in "$SCRIPT_DIR/templates/skills"/*/; do
        skill_name=$(basename "$skill_dir")
        cp -r "$skill_dir" "$CLAUDE_DIR/skills/$skill_name"
        echo "  Installed skill: $skill_name → ~/.claude/skills/"
    done
fi

# --- Step 4: claude-init in PATH ---
mkdir -p "$HOME/bin"
ln -sf "$CLAUDE_DIR/templates/claude-init.sh" "$HOME/bin/claude-init"
echo "  Symlinked ~/bin/claude-init"

# Check PATH
if echo "$PATH" | tr ':' '\n' | grep -q "$HOME/bin"; then
    echo ""
    echo "Done. 'claude-init' is ready to use."
else
    echo ""
    echo "Done. Add ~/bin to your PATH:"
    echo '  echo '\''export PATH="$HOME/bin:$PATH"'\'' >> ~/.zshrc && source ~/.zshrc'
fi

echo ""
echo "Usage:"
echo "  cd ~/Documents/my-project"
echo "  claude-init \"Project Name\" \"Description\""
echo ""
echo "Hooks are global — any project with memory/episodes/ gets automatic episodic capture."
