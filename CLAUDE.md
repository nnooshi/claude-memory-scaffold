# Global Memory Protocol

## Memory Architecture

All projects use in-project memory. Never store memory in `~/.claude/projects/*/memory/`.

### Where Memory Lives
- **Project memory**: `./memory/` relative to the project's CLAUDE.md
- **Auto-loaded**: `CLAUDE.md` (lean router) + `memory/MEMORY.md` (index, ~200 lines max)
- **Demand-loaded**: All other `memory/*.md` files — read only when the topic comes up
- **Episodic**: `memory/episodes/YYYY-MM-DD.md` — auto-maintained by hooks
- **Never**: `~/.claude/projects/` — this is for session transcripts only, not memory

### Memory Discipline
1. **CLAUDE.md is a router, not a database.** Max ~800-1000 tokens. Contains: identity, knowledge map with "read X before answering Y" instructions, preferences. Nothing else.
2. **MEMORY.md is the index.** Max 200 lines. Contains: current state, active items, routing table to topic files.
3. **One fact, one place.** Each piece of knowledge lives in ONE file. Everything else points to it.
4. **Every memory file starts with**: `**Last updated:** YYYY-MM-DD` on line 2.
5. **Be selective.** Not everything is worth remembering. Filter for durable knowledge.

### Episodic Memory
Episodes are captured automatically by PreCompact and Stop hooks. Each entry is tagged:
- `DECISION` — a choice was made
- `FACT_LEARNED` — new information discovered
- `CORRECTION` — existing memory was wrong, now fixed
- `ACTION_ITEM` — something to do later
- `PREFERENCE` — user workflow/style preference discovered

### Weekly Consolidation
When working in a project with 7+ days of episodes:
1. Scan `memory/episodes/` for the past week
2. Promote any DECISION or CORRECTION still relevant into the appropriate semantic memory file
3. Summarize the week's episodes into `memory/episodes/archive/YYYY-WNN.md`
4. Update MEMORY.md if current state changed

### Retrieval
Before answering questions about past work, decisions, or events:
1. Check `memory/MEMORY.md` routing table for the right file
2. If topic-specific: read the relevant `memory/*.md` file
3. If historical/episodic: `grep` across `memory/episodes/*.md` for keywords
4. Use tags for precise retrieval: `grep "DECISION" memory/episodes/*.md`

## Owner
Nima Nooshi (nnooshi@gmail.com) — Freelance Data & AI Architect, Munich
