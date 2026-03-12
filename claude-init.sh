#!/bin/bash
# claude-init: Initialize a new project with the standard memory architecture
#
# Usage:
#   claude-init "My Project Name" "One-line description"
#   claude-init  (interactive mode)
#
# What it does:
#   1. Creates memory/ directory structure (episodes/, archive/, people/, context/)
#   2. Creates CLAUDE.md from template (if none exists)
#   3. Creates memory/MEMORY.md index
#   4. Creates memory/decisions.md
#   5. Does NOT overwrite existing files
#
# Prerequisites:
#   - Global hooks in ~/.claude/settings.json (handles episodic capture)
#   - Global memory protocol in ~/.claude/CLAUDE.md

set -euo pipefail

TEMPLATE_DIR="$HOME/.claude/templates/project-scaffold"
DATE=$(date +%Y-%m-%d)

# Get project name
if [ -n "${1:-}" ]; then
    PROJECT_NAME="$1"
else
    read -p "Project name: " PROJECT_NAME
fi

# Get description
if [ -n "${2:-}" ]; then
    DESCRIPTION="$2"
else
    read -p "One-line description: " DESCRIPTION
fi

echo "Initializing memory architecture for: $PROJECT_NAME"
echo "Location: $(pwd)"
echo ""

# Create directory structure
mkdir -p memory/episodes/archive
mkdir -p memory/people
mkdir -p memory/context
echo "  Created memory/ directory structure"

# Create CLAUDE.md (if not exists)
if [ ! -f CLAUDE.md ]; then
    sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
        -e "s/{{ONE_LINE_DESCRIPTION}}/$DESCRIPTION/g" \
        -e "s/{{DATE}}/$DATE/g" \
        "$TEMPLATE_DIR/CLAUDE.md" > CLAUDE.md
    echo "  Created CLAUDE.md (from template — edit the {{placeholders}})"
else
    echo "  CLAUDE.md already exists — skipped"
fi

# Create memory/MEMORY.md (if not exists)
if [ ! -f memory/MEMORY.md ]; then
    sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
        -e "s/{{DATE}}/$DATE/g" \
        -e "s/{{STATUS}}/New project/g" \
        -e "s/{{CURRENT_FOCUS}}/Initial setup/g" \
        -e "s/{{NEXT_ACTION}}/Define project scope/g" \
        "$TEMPLATE_DIR/memory/MEMORY.md" > memory/MEMORY.md
    echo "  Created memory/MEMORY.md"
else
    echo "  memory/MEMORY.md already exists — skipped"
fi

# Create memory/decisions.md (if not exists)
if [ ! -f memory/decisions.md ]; then
    sed -e "s/{{DATE}}/$DATE/g" \
        "$TEMPLATE_DIR/memory/decisions.md" > memory/decisions.md
    echo "  Created memory/decisions.md"
else
    echo "  memory/decisions.md already exists — skipped"
fi

# Create .gitkeep files for empty dirs
touch memory/episodes/.gitkeep
touch memory/episodes/archive/.gitkeep

echo ""
echo "Done. Memory architecture initialized."
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md — replace {{placeholders}} with project-specific content"
echo "  2. Edit memory/MEMORY.md — set initial state and routing table"
echo "  3. Start a Claude Code session in this directory"
echo ""
echo "Hooks are global (in ~/.claude/settings.json) — MEMORY.md auto-loads at session start."
echo "Write episodes manually: tell Claude 'save', 'wrap up', or 'that's all' at session end."
