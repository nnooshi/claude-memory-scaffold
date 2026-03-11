# Claude Memory Scaffold

A standardized memory architecture for Claude Code projects. Provides episodic memory capture, progressive disclosure, and cross-session knowledge persistence — all using plain Markdown files.

## The Problem

Claude Code loses session knowledge when conversations end or context compresses. Memory gets scattered across `~/.claude/projects/` in flat, unsearchable folders. Projects duplicate facts with no single source of truth. There's no mechanism to capture decisions, corrections, or learnings across sessions.

## The Solution

1. **In-project memory** — all memory lives next to your code in `memory/`, not in `~/.claude/projects/`
2. **Lean CLAUDE.md** — a router (~800 tokens), not a knowledge dump
3. **Episodic hooks** — PreCompact + Stop hooks automatically extract durable memories before context is lost
4. **Progressive disclosure** — only load what's needed, when it's needed
5. **Tagged episodes** — DECISION, FACT_LEARNED, CORRECTION, ACTION_ITEM, PREFERENCE

## Architecture

```
project/
├── CLAUDE.md                  ← Lean router: identity + knowledge map + preferences
├── memory/
│   ├── MEMORY.md              ← Auto-loaded index (~200 lines max)
│   ├── decisions.md           ← Decision log with rationale
│   ├── episodes/              ← Daily episodic logs (auto-captured by hooks)
│   │   ├── 2026-03-11.md
│   │   └── archive/           ← Weekly consolidated summaries
│   ├── [topic].md             ← Semantic memory (demand-loaded)
│   ├── people/                ← People profiles (demand-loaded)
│   └── context/               ← Reference docs (demand-loaded)
└── .claude/
    └── settings.json          ← Project-specific hooks (optional, global hooks cover this)
```

### Memory Types

| Type | Where | Loading | Example |
|------|-------|---------|---------|
| **Procedural** | `CLAUDE.md` | Always loaded | Workflows, preferences, loading instructions |
| **Semantic** | `memory/*.md` | On demand | Facts, people, domain knowledge |
| **Episodic** | `memory/episodes/` | Auto-captured | Decisions, corrections, learnings |

### Hook Chain

```
PreCompact (before context compression)
  → Agent extracts tagged episodic memories → memory/episodes/YYYY-MM-DD.md

Stop (session end)
  → Agent extracts remaining memories → updates MEMORY.md if state changed

SessionStart (after compaction)
  → Re-injects today + yesterday episodes into compressed context
```

## Installation

```bash
# Clone
git clone https://github.com/nnooshi/claude-memory-scaffold.git
cd claude-memory-scaffold

# Install (copies global config + makes claude-init available)
./install.sh
```

### Manual Installation

```bash
# 1. Copy global CLAUDE.md (memory protocol for all projects)
cp CLAUDE.md ~/.claude/CLAUDE.md

# 2. Merge hooks into your settings.json
#    (review settings.json and merge the "hooks" section into ~/.claude/settings.json)

# 3. Copy templates + init script
mkdir -p ~/.claude/templates
cp -r templates/* ~/.claude/templates/
cp claude-init.sh ~/.claude/templates/
chmod +x ~/.claude/templates/claude-init.sh

# 4. Make claude-init available in PATH
mkdir -p ~/bin
ln -sf ~/.claude/templates/claude-init.sh ~/bin/claude-init
# Add to ~/.zshrc if not already: export PATH="$HOME/bin:$PATH"
```

## Usage

### Initialize a New Project

```bash
cd ~/Documents/my-new-project
claude-init "My Project" "One-line description"
```

This creates the full `memory/` structure, CLAUDE.md template, and MEMORY.md index. Edit the `{{placeholders}}` to customize.

### Existing Projects

For projects that already have a CLAUDE.md, run `claude-init` — it will create the memory structure without overwriting existing files.

### How Episodic Capture Works

Once the global hooks are installed, any project with a `memory/episodes/` directory gets automatic episodic capture:

- **PreCompact**: Before Claude Code compresses context, a haiku agent extracts durable memories and appends tagged entries to `memory/episodes/YYYY-MM-DD.md`
- **Stop**: At session end, any remaining unsaved memories are extracted
- **Post-compaction**: Today's and yesterday's episodes are re-injected into the compressed context

Projects without `memory/episodes/` are unaffected — the hooks self-guard.

### Episode Format

```markdown
## 14:32 — [DECISION]
Chose Liquid Clustering over ZORDER for the EEO tables — better for evolving query patterns.

## 15:01 — [FACT_LEARNED]
Maksim confirmed both tables are Delta format, not raw Parquet as originally assumed.

## 15:45 — [CORRECTION]
Time recording deadline is 3rd workday, not 5th. Updated contract-compliance.md.
```

### Retrieval

At current scale (<100 episode files), grep-based retrieval beats vector search:

```bash
# Find all decisions
grep "DECISION" memory/episodes/*.md

# Find mentions of a person
grep -r "Maksim" memory/episodes/

# Find corrections (things we got wrong)
grep "CORRECTION" memory/episodes/*.md
```

### Weekly Consolidation

When 7+ days of episodes accumulate:
1. Promote durable DECISION and CORRECTION entries into semantic memory files
2. Archive daily episodes into `memory/episodes/archive/YYYY-WNN.md`
3. Update MEMORY.md if project state changed

## Design Principles

1. **Files are truth, not RAM** — if it's not on disk, it doesn't exist
2. **One fact, one place** — each piece of knowledge lives in ONE file; everything else points to it
3. **CLAUDE.md is a router, not a database** — max ~800-1000 tokens
4. **MEMORY.md is an index** — max 200 lines, routing table to topic files
5. **Progressive disclosure** — auto-load only CLAUDE.md + MEMORY.md; everything else on demand
6. **Be selective** — not everything is worth remembering; filter for durable knowledge
7. **Context rot is real** — more tokens = worse reasoning; keep auto-loaded content minimal

## References

- [Google: Context Engineering — Sessions & Memory](https://www.kaggle.com/whitepaper-context-engineering-sessions-and-memory) (Nov 2025)
- [How AI Agents Remember Things](https://www.damiangalarza.com/posts/2026-02-17-how-ai-agents-remember-things/) — Damian Galarza
- [OpenClaw Memory Implementation](https://github.com/openclaw/openclaw) — reference implementation
- Full assessment: [docs/memory-architecture-assessment.md](docs/memory-architecture-assessment.md)

## License

MIT
