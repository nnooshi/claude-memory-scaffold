---
name: brief
description: >
  Morning/resumption briefing synthesized from the project's episodic memory.
  Reads MEMORY.md (current state) + last N days of episode files, then produces
  a narrative summary: what happened, what was learned, decisions made, and
  what's still open — so the user can pick up work without re-reading raw files.
  Triggers: /brief, /brief [N], "give me a brief", "catch me up", "what did we
  do last week", "where did we leave off", "bring me up to speed".
  Default N = 7 days. Requires memory scaffold (memory/MEMORY.md + memory/episodes/).
---

# /brief

## Runtime Guard

First: check if `memory/MEMORY.md` exists in the current working directory.

If it does NOT exist → stop and respond:
> "This project has no memory structure. Initialize it first with `claude-init`:
> github.com/nnooshi/claude-memory-scaffold"

## Step 1 — Parse Parameter

Extract N from the argument (default 7 if none given).
- `/brief` → N = 7
- `/brief 3` → N = 3
- `/brief 1` → N = 1 (yesterday + today)

## Step 2 — Read MEMORY.md

Read `memory/MEMORY.md` in full. This is the declared current state.

## Step 3 — Collect Episode Files

Build the list of dates from today going back N days. For each date YYYY-MM-DD:
1. Check `memory/episodes/YYYY-MM-DD.md` (top-level project)
2. Check `*/memory/episodes/YYYY-MM-DD.md` (subproject dirs — one level deep)

Read every file that exists. Note which subproject each file belongs to (from path).
If no episode files exist in the period, note it in the output.

## Step 4 — Synthesize

Do NOT dump raw episode content. Synthesize across all files.

**Action Item Tracking (`[OPEN]` / `[DONE]`):**
- `[OPEN]` with no `[DONE]` counterpart in any later episode = still open
- `[OPEN]` followed by `[DONE]` in a later episode = resolved, omit from open list

**MEMORY.md Drift Detection:**
Compare episodes against MEMORY.md. Flag significant facts, decisions, or state
changes in episodes that are NOT yet reflected in MEMORY.md. Propose specific updates.

## Step 5 — Output

```
# Brief — [Project Name] | [date range]

## Current State
[2-4 bullets from MEMORY.md. Mark stale items with ⚠️ if episodes contradict them.]

## What Happened
[Narrative grouped by subproject/area if multiple. One short paragraph per area.
 Synthesized prose — not raw bullet dumps. Chronological within each area.]

## What Was Learned
[Facts discovered and corrections made. Bullets, one line each.]

## Decisions Made
[Decisions from the period. Bullets, one line each. Omit section if empty.]

## Open Action Items
[OPEN items with no DONE counterpart. Include originating date.
 If none: "No open action items in this period ✓"]

## MEMORY.md Drift
[Suggested additions/changes: "Add to [section]: [proposed text]"
 If current: "MEMORY.md appears current ✓"]
```

Keep total output scannable in under 2 minutes. If many sessions, summarize
trends rather than enumerating every session individually.
