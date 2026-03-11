# Memory Architecture Assessment

**Audit of Claude Code Memory Systems Across Four Projects**
Last updated: 2026-03-11
Author: Nima Nooshi (with Claude)
Status: Canonical Reference

---

## 1. Executive Summary

We conducted a memory architecture audit across four Claude Code projects (Quant Agent Factory, RWE Project, RFP Project, Investment Project) and evaluated them against best practices drawn from Google's "Context Engineering" whitepaper (Nov 2025), Damian Galarza's article on agentic memory, and the OpenClaw open-source implementation. The central finding is that memory is split between in-project folders and `~/.claude/projects/` with no synchronization mechanism, causing duplication, contradictions, and knowledge loss across sessions. Quant Agent Factory scored highest (8/10) due to its progressive loading and lesson ID system, while the Investment Project scored lowest (4/10) due to a bloated CLAUDE.md, massive duplication, and no loading instructions. The recommended solution is to standardize all projects on in-project `memory/` folders, eliminate `~/.claude/projects/*/memory/`, adopt a lean CLAUDE.md router pattern, and implement episodic memory capture via PreCompact, Stop, and SessionStart hooks.

---

## 2. Reference Framework

### 2.1 Google's "Context Engineering" Whitepaper (Nov 2025)

Google's whitepaper establishes that context management is not a side concern but the primary engineering challenge in building effective LLM-based agents. The key principles are:

| Principle | Description |
|---|---|
| **Context Rot** | More tokens in the context window does not mean better reasoning. Beyond a threshold, accuracy degrades as the model struggles to attend to the right information. |
| **Memory as ETL Pipeline** | Memory should follow an Extract-Transform-Load pattern: extract salient facts from sessions, consolidate into durable storage, load on demand. |
| **Three Memory Types** | *Semantic memory* (facts, definitions, domain knowledge), *episodic memory* (events, decisions, what happened when), *procedural memory* (how-to instructions, workflows, recipes). |
| **Blended Retrieval** | Effective retrieval combines relevance scoring, recency weighting, and importance ranking rather than relying on any single signal. |
| **Progressive Disclosure** | Load information on demand, not upfront. Auto-loaded content should be minimal; everything else is pulled in when the agent needs it. |
| **Token Budgeting** | Auto-loaded content (CLAUDE.md, MEMORY.md) must stay within a strict token budget. Large auto-loaded files cause context rot from the first turn. |
| **Memory-as-a-Tool** | The agent should have explicit tools (or tool-like patterns) for reading and writing memory, rather than relying on passive context injection. |
| **Seven Principles** | (1) Write instructions as if for a new hire. (2) Show, don't tell. (3) Use delimiters and structure. (4) Specify output format. (5) Provide fallback behavior. (6) Build in self-checks. (7) Keep context lean and relevant. |

### 2.2 Galarza's "How AI Agents Remember" Article

Galarza's article focuses on practical patterns for memory in agentic coding assistants, with an emphasis on simplicity and debuggability:

| Pattern | Description |
|---|---|
| **Write-Ahead Log** | Save episodic memories to disk *before* context compaction occurs, ensuring no knowledge is lost when the context window is compressed. |
| **MEMORY.md as Lean Index** | MEMORY.md should be approximately 200 lines maximum, serving as a routing table that points to detailed files rather than containing the details itself. |
| **Four Write Mechanisms** | (1) *Bootstrap*: initial population when a project is first set up. (2) *Pre-compaction flush*: triggered before context compression. (3) *Session snapshot*: periodic saves during a session. (4) *Explicit save*: user-triggered writes. |
| **Proactive Loading > On-Demand** | For small-scale agents (fewer than ~100 memory files), proactively loading a lean index outperforms on-demand vector retrieval because the retrieval overhead exceeds the cost of a small always-loaded file. |
| **Markdown Files as Storage** | Markdown is human-readable, debuggable, version-controllable, and diff-friendly. No database required at our scale. |

### 2.3 OpenClaw Implementation

OpenClaw is an open-source reference implementation that demonstrates a production-grade memory system for Claude Code:

| Feature | Implementation Detail |
|---|---|
| **Hybrid Search** | BM25 (keyword) + vector embeddings with 0.7/0.3 weighting. BM25 handles exact matches; vectors handle semantic similarity. |
| **Temporal Decay** | 30-day half-life on memory relevance. Older memories score lower unless tagged as evergreen (MEMORY.md is always exempt). |
| **MMR Re-Ranking** | Maximal Marginal Relevance re-ranking prevents duplicate or near-duplicate results from dominating retrieval. |
| **PreCompact Hook** | A silent agentic turn fires before context compaction, extracting episodic memories and writing them to disk. |
| **Session Snapshots** | LLM-generated slugs create human-readable filenames for session snapshots (e.g., `2026-03-11-pipeline-status-fix.md`). |
| **Local-First Embeddings** | Uses `embeddinggemma-300m` for on-device embedding generation. No API calls for memory retrieval. |
| **Files Are Truth** | The filesystem is the single source of truth, not in-memory data structures. If it is not on disk, it does not exist. |

---

## 3. Per-Project Assessment

### 3.1 Quant Agent Factory -- Score: 8/10

**Strengths:**

- L1/L2/L3 progressive loading system is well-designed and aligns with Google's progressive disclosure principle. L1 loads the CLAUDE.md router, L2 loads domain-specific context on demand, L3 loads reference data only when explicitly needed.
- Lesson ID system (e.g., `LESSON-042`) provides traceable episodic memory with unique identifiers, enabling grep-based retrieval.
- Changelog functions as an episodic log, capturing what changed and why with timestamps.

**Weaknesses:**

- Pipeline status is tracked in three places (STATUS.md, CLAUDE.md summary, and changelog), creating a 3-way sync problem where updates in one location do not propagate to the others.
- STATUS.md is always-loaded, consuming tokens every session even when pipeline status is not relevant to the task at hand.
- No local `memory/` folder exists in the project; all memory resides in `~/.claude/projects/`, making it invisible to version control and detached from the codebase.

**Migration Steps:**

1. Create `quant_app/memory/` directory with MEMORY.md index.
2. Move the 5 memory files from `~/.claude/projects/` into `quant_app/memory/`.
3. Eliminate pipeline status duplication by making STATUS.md the single source and having CLAUDE.md reference it rather than summarize it.
4. Make STATUS.md demand-loaded (remove from auto-load, add loading instruction in CLAUDE.md).

### 3.2 RWE Project -- Score: 6.5/10

**Strengths:**

- Progressive disclosure knowledge map in CLAUDE.md effectively routes the agent to the right files for different task types.
- Sub-project CLAUDE.md isolation (e.g., `team_eeo/CLAUDE.md`, `team_european_power/CLAUDE.md`) correctly scopes context to sub-domains.

**Weaknesses:**

- Split-brain memory: information exists both in the project's `memory/` folder and in `~/.claude/projects/`, with no synchronization. Facts updated in one location remain stale in the other.
- Contradictory deadlines: the 3rd workday deadline appears in one location while the 5th workday appears in another, with no indication of which is current.
- Session routine context pollution: the daily session startup routine is auto-loaded in CLAUDE.md, consuming tokens even for tasks that do not require the routine.
- Shadow copies in `memory/projects/` duplicate information already present in sub-project CLAUDE.md files.

**Migration Steps:**

1. Merge content from `~/.claude/projects/` into `memory/`, resolving contradictions (confirm 3rd vs 5th workday with Nima).
2. Delete shadow copies in `memory/projects/`.
3. Slim CLAUDE.md to a lean router (~800-1,000 tokens), moving domain knowledge into `memory/` topic files.
4. Make session routine conditional: load only when the task involves daily operations.

### 3.3 RFP Project -- Score: 5/10

**Strengths:**

- `master-profile.md` is well-structured with clear sections for company overview, engagement history, and capabilities.
- Lean total footprint: the project does not suffer from excessive memory bloat.

**Weaknesses:**

- Stale profile: `master-profile.md` was last updated on Feb 19, missing approximately three weeks of engagement activity.
- Workflow documentation appears in four separate locations with slight variations, violating the single-source-of-truth principle.
- The `.claude` MEMORY.md contains information (e.g., client preferences, submission feedback) that does not appear anywhere in the project, creating a hidden knowledge silo.
- Broken file paths in `rfp-monitor-prompt.md` reference directories that have been moved or renamed.

**Migration Steps:**

1. Merge content from `.claude` MEMORY.md into `memory/MEMORY.md`, ensuring no knowledge is lost.
2. Update `master-profile.md` with current engagement data and add a `Last updated:` header.
3. Consolidate the four workflow instances into a single `memory/workflow.md` and replace the other three with references.
4. Fix broken paths in `rfp-monitor-prompt.md`.

### 3.4 Investment Project -- Score: 4/10

**Strengths:**

- Well-organized `memory/` subfolder structure with logical groupings (companies, deals, research).
- Thorough content: when information is captured, it is detailed and well-written.

**Weaknesses:**

- CLAUDE.md is approximately 3,500 tokens and reads as an investment memo rather than a lean router. It contains deal terms, company descriptions, and market analysis that belong in memory files.
- Massive duplication: M&A comparable transactions appear in four separate files, drug definitions appear in three files, and there is no indication of which is the authoritative source.
- Exhibit A contradiction: the exhibit data in one file conflicts with the exhibit data in another, with no resolution.
- No loading instructions: CLAUDE.md does not tell the agent where to find information or when to load specific files.
- Sensitive PII (names, deal terms, financial figures) is auto-loaded in CLAUDE.md rather than demand-loaded from protected files.

**Migration Steps:**

1. Gut CLAUDE.md from ~3,500 tokens to ~1,000 tokens, retaining only identity, knowledge map, loading instructions, and preferences.
2. Move deal terms, company descriptions, and market analysis into `memory/` topic files.
3. Establish single source of truth per data domain: one file for M&A comps, one file for drug definitions, one file for exhibit data.
4. Resolve the Exhibit A contradiction.
5. Create `memory/MEMORY.md` as an index/routing table.
6. Add loading instructions to CLAUDE.md so the agent knows which files to read for which task types.

---

## 4. Cross-Project Anti-Patterns

| # | Anti-Pattern | Affected Projects | Severity |
|---|---|---|---|
| 1 | **CLAUDE.md as knowledge dump** -- CLAUDE.md contains domain knowledge, deal terms, or operational details instead of serving as a lean router. | Investment (severe), RWE (moderate) | High |
| 2 | **Split-brain memory** -- Information exists in both project folders and `~/.claude/projects/` with no sync mechanism. Updates in one location do not propagate. | All four projects | Critical |
| 3 | **No memory lifecycle** -- Memory files are created but never updated, consolidated, or archived. Stale information accumulates indefinitely. | RFP, Investment | High |
| 4 | **Duplication without ownership** -- The same fact appears in multiple files with no designated authoritative source. When one copy is updated, the others become stale or contradictory. | RWE, Investment | High |
| 5 | **No loading instructions** -- CLAUDE.md does not tell the agent where to find information or when to load specific files, so the agent either loads everything or misses critical context. | Investment, RFP | Medium |
| 6 | **Context pollution via session routine** -- Always-loaded session startup routines consume tokens even when irrelevant to the current task. | RWE | Medium |
| 7 | **No episodic memory capture** -- No mechanism to capture decisions, corrections, or learned facts during a session. Knowledge exists only in the context window and is lost on compaction or session end. | All four projects | Critical |
| 8 | **No decision log** -- Decisions are made during sessions but not recorded anywhere persistent. The same decisions are re-debated in future sessions. | All except Quant (which uses changelog as a partial substitute) | High |

---

## 5. Target Architecture

### 5.1 Directory Structure

```
project-folder/
├── CLAUDE.md                  <- Lean router (~800-1,000 tokens)
├── .claude/
│   └── settings.json          <- Hooks: PreCompact, Stop, SessionStart
├── memory/
│   ├── MEMORY.md              <- Auto-loaded index (~200 lines max)
│   ├── decisions.md           <- Decision log (append-only)
│   ├── episodes/              <- Episodic memory (auto-maintained by hooks)
│   │   ├── YYYY-MM-DD.md      <- Daily episode files
│   │   └── archive/           <- Weekly consolidated summaries
│   ├── [topic].md             <- Semantic memory (demand-loaded)
│   ├── people/                <- People profiles (demand-loaded)
│   └── context/               <- Reference documents (demand-loaded)
└── [project files]
```

### 5.2 Architecture Rules

| Rule | Description |
|---|---|
| **Rule 1: CLAUDE.md = Router Only** | CLAUDE.md contains four sections and nothing else: (1) Project identity (2-3 lines), (2) Knowledge map (file listing with one-line descriptions), (3) Loading instructions (when to read which files), (4) Preferences (coding style, conventions). Target: 800-1,000 tokens. |
| **Rule 2: MEMORY.md = State + Routing** | MEMORY.md contains current project state, active tasks, and a routing table that maps topics to files. Hard cap: 200 lines. If it exceeds 200 lines, promote durable content to topic files and trim. |
| **Rule 3: Single Source of Truth** | Each fact lives in exactly ONE file. Every other file that needs that fact references it by path rather than duplicating it. Example: M&A comps live in `memory/ma-comps.md`; CLAUDE.md and MEMORY.md reference the path, not the data. |
| **Rule 4: No ~/.claude/projects/ Memory** | `~/.claude/projects/*/memory/` is eliminated entirely. All memory lives in the project's `memory/` folder, under version control, visible to the developer. |
| **Rule 5: Freshness Headers** | Every memory file has `Last updated: YYYY-MM-DD` on line 2. This enables temporal retrieval and staleness detection. Files not updated in 30+ days are candidates for review. |
| **Rule 6: Episode Tagging** | Every entry in an episode file is tagged with one of: `DECISION`, `FACT_LEARNED`, `CORRECTION`, `ACTION_ITEM`, `PREFERENCE`. Tags enable grep-based retrieval by category. |
| **Rule 7: Weekly Consolidation** | Weekly consolidation cycle: promote durable facts from daily episodes to semantic memory files, archive daily episodes to `episodes/archive/`, update MEMORY.md routing table. |

### 5.3 CLAUDE.md Template

```markdown
# [Project Name]

[2-3 sentence project description]

## Knowledge Map

- `memory/MEMORY.md` -- Current state, active tasks, routing table (auto-loaded)
- `memory/decisions.md` -- Decision log
- `memory/episodes/` -- Daily session logs
- `memory/[topic].md` -- [Description]
- `memory/people/[name].md` -- [Description]
- `memory/context/[doc].md` -- [Description]

## Loading Instructions

- Always read `memory/MEMORY.md` at session start.
- Read topic files only when the task involves that topic.
- Read `memory/decisions.md` when making architectural or strategic decisions.
- Read recent episodes (`memory/episodes/`) when resuming interrupted work.

## Preferences

- [Coding style, conventions, formatting rules]
- [Communication preferences]
- [Tool preferences]
```

---

## 6. Episodic Memory & Hooks Architecture

### 6.1 Hook Chain Overview

The hook chain ensures that episodic memories are captured at every critical transition point in a session:

```
Session Start
    │
    ▼
[SessionStart hook] ── Re-inject today's episodes after compaction
    │
    ▼
... agent works ...
    │
    ▼
[PreCompact hook] ── Extract episodic memories before context compression
    │
    ▼
... context compacted, agent continues ...
    │
    ▼
[Stop hook] ── Extract remaining memories, update MEMORY.md
    │
    ▼
Session End
```

### 6.2 PreCompact Hook

**Trigger:** Fires automatically before Claude Code compresses the context window.

**Behavior:** The agent performs a silent agentic turn (no user-visible output) that:

1. Reviews the current context for salient information: decisions made, facts learned, corrections applied, action items identified, preferences expressed.
2. Writes tagged entries to today's episode file (`memory/episodes/YYYY-MM-DD.md`).
3. Updates `memory/MEMORY.md` if current state has changed.

**Configuration (`.claude/settings.json`):**

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "command": "cat memory/episodes/$(date +%Y-%m-%d).md 2>/dev/null || echo '# Episodes for '$(date +%Y-%m-%d)"
      }
    ]
  }
}
```

Note: The PreCompact hook in Claude Code triggers an agentic turn where the agent is instructed (via CLAUDE.md or global instructions) to flush episodic memories. The hook command above injects today's existing episodes into the compaction context so the agent can see what has already been captured and avoid duplication.

### 6.3 Stop Hook

**Trigger:** Fires when the session ends (user exits or conversation closes).

**Behavior:**

1. Extract any remaining episodic memories not yet written.
2. Append tagged entries to today's episode file.
3. Update `memory/MEMORY.md` with final session state.
4. If decisions were made, append to `memory/decisions.md`.

### 6.4 SessionStart Hook (Compact Matcher)

**Trigger:** Fires at the beginning of a session or after context compaction.

**Behavior:**

1. Re-inject today's episode file into context so the agent has continuity.
2. Re-inject `memory/MEMORY.md` for current state awareness.

**Configuration:**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "compact",
        "command": "echo '--- Restored Episodes ---' && cat memory/episodes/$(date +%Y-%m-%d).md 2>/dev/null && echo '--- End Episodes ---'"
      }
    ]
  }
}
```

### 6.5 Episode File Format

```markdown
# Episodes for 2026-03-11
Last updated: 2026-03-11

## 14:32 [DECISION]
Chose to use grep-based retrieval instead of vector search for memory lookup.
Rationale: fewer than 100 memory files; grep is faster and has zero dependencies.

## 15:01 [FACT_LEARNED]
The RWE timesheet deadline is the 3rd workday, not the 5th. Confirmed by Nima.

## 15:45 [CORRECTION]
Previously believed Investment Exhibit A showed $12M valuation. Actual value is $14M.
Corrected in memory/investment/exhibit-a.md.

## 16:10 [ACTION_ITEM]
TODO: Update master-profile.md with March engagement data.
Assigned: Next session.

## 16:30 [PREFERENCE]
Nima prefers tables over bullet lists for comparison data.
```

### 6.6 Consolidation Cadence

| Cadence | Action | Details |
|---|---|---|
| **Daily** | Auto-capture | Hooks write to `memory/episodes/YYYY-MM-DD.md` throughout the session. No manual effort required. |
| **Weekly** | Promote + Archive | Review the week's episode files. Promote durable facts (FACT_LEARNED, PREFERENCE) to the appropriate semantic memory file. Move completed ACTION_ITEMs to a done section. Move daily files to `episodes/archive/`. |
| **Monthly** | Prune + Compact | Review `episodes/archive/` for the month. Consolidate weekly archives into a monthly summary. Delete low-value entries. Update MEMORY.md routing table if new topic files were created. |

---

## 7. Retrieval Strategy

### 7.1 Phase 1: Grep-Based Retrieval (Current Scale)

At our current scale (fewer than 100 memory files across all projects), grep-based retrieval outperforms embedding-based retrieval for three reasons:

1. **Zero infrastructure:** No embedding model to install, no vector database to maintain, no API costs.
2. **Deterministic results:** Grep returns exact matches. There is no relevance threshold to tune or hallucinated similarity to debug.
3. **Speed:** Grep over 100 markdown files completes in milliseconds. Embedding generation + vector search adds latency with no accuracy benefit at this scale.

This aligns with findings from Augment's SWE-Bench research, which showed that keyword-based retrieval (BM25) matched or exceeded vector retrieval for code-related queries at scales below several hundred files, because code and technical documentation use precise terminology where exact keyword matching is highly effective.

**Tag-Based Retrieval Examples:**

```bash
# Find all decisions across all projects
grep -r "DECISION" memory/episodes/*.md

# Find facts learned this week
grep -r "FACT_LEARNED" memory/episodes/2026-03-0*.md

# Find all corrections (useful for detecting recurring mistakes)
grep -r "CORRECTION" memory/episodes/*.md

# Find open action items
grep -r "ACTION_ITEM" memory/episodes/*.md | grep -v "DONE"
```

**Temporal Retrieval:**

File names provide natural date ordering. To find what happened last week:
```bash
ls memory/episodes/2026-03-0[4-8].md
```

### 7.2 Phase 2: Hybrid Retrieval (100+ Episode Files)

When the cumulative episode count exceeds approximately 100 files, consider adopting a hybrid retrieval strategy modeled on OpenClaw:

| Component | Weight | Purpose |
|---|---|---|
| BM25 (keyword) | 0.7 | Handles exact terminology, names, identifiers |
| Vector (semantic) | 0.3 | Handles paraphrased queries, conceptual similarity |
| Temporal decay | 30-day half-life | Older memories score lower unless tagged evergreen |
| MMR re-ranking | lambda=0.7 | Prevents near-duplicate results from dominating |

**Implementation options at Phase 2:**

- Local-first embeddings using `embeddinggemma-300m` (OpenClaw's approach) for zero-API-cost operation.
- A lightweight SQLite-backed index with FTS5 for BM25 and a vector extension for embeddings.
- Evergreen exemption: MEMORY.md and decisions.md are exempt from temporal decay.

**Trigger for Phase 2:** When `find memory/episodes/ -name "*.md" | wc -l` exceeds 100 (excluding archived files).

### 7.3 Why Grep Beats Embeddings at Our Scale

The decision to start with grep is not a compromise; it is the optimal choice for small-scale memory systems:

- **Precision:** At small scale, recall is not the problem. We are not searching thousands of documents hoping to find the one relevant passage. We have tens of files and need exact matches. Grep has perfect precision for keyword queries.
- **Transparency:** When grep returns a result, we know exactly why. When an embedding model returns a result, we cannot inspect the reasoning. Debuggability matters for a system we are actively tuning.
- **Maintenance:** Grep requires zero maintenance. Embedding indices require re-indexing when files change, model updates when better embeddings become available, and parameter tuning when retrieval quality degrades.

---

## 8. Scaffold Design

### 8.1 Global Configuration

The global `~/.claude/CLAUDE.md` establishes the memory protocol that all projects inherit:

```markdown
# Global Claude Code Configuration

## Memory Protocol

When working in any project:
1. Read `memory/MEMORY.md` at session start if it exists.
2. Before context compaction, write episodic memories to `memory/episodes/YYYY-MM-DD.md`.
3. Tag every episode entry: DECISION | FACT_LEARNED | CORRECTION | ACTION_ITEM | PREFERENCE.
4. At session end, update `memory/MEMORY.md` with current state.
5. Never duplicate facts. Reference by path instead.
6. Keep MEMORY.md under 200 lines.
```

The global `~/.claude/settings.json` provides hooks that fire for every project:

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "command": "cat memory/episodes/$(date +%Y-%m-%d).md 2>/dev/null || true"
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "command": "cat memory/MEMORY.md 2>/dev/null || true"
      }
    ]
  }
}
```

### 8.2 Template Directory Structure

A `claude-init` script (or manual template) sets up the standard memory structure for new projects:

```
memory/
├── MEMORY.md              <- Created with header and empty routing table
├── decisions.md           <- Created with header
├── episodes/              <- Created empty
│   └── archive/           <- Created empty
└── context/               <- Created empty
```

### 8.3 `claude-init` Script Concept

```bash
#!/bin/bash
# claude-init: Initialize Claude Code memory structure for a project

PROJECT_DIR="${1:-.}"
MEMORY_DIR="$PROJECT_DIR/memory"

mkdir -p "$MEMORY_DIR/episodes/archive"
mkdir -p "$MEMORY_DIR/people"
mkdir -p "$MEMORY_DIR/context"

# Create MEMORY.md
cat > "$MEMORY_DIR/MEMORY.md" << 'EOF'
# Memory Index
Last updated: $(date +%Y-%m-%d)

## Current State
[Describe active work, blockers, next steps]

## Routing Table
| Topic | File | Description |
|---|---|---|
| Decisions | decisions.md | Decision log |
| Episodes | episodes/ | Daily session logs |

## Active Action Items
- None yet
EOF

# Create decisions.md
cat > "$MEMORY_DIR/decisions.md" << 'EOF'
# Decision Log
Last updated: $(date +%Y-%m-%d)

| Date | Decision | Rationale | Status |
|---|---|---|---|
EOF

# Create CLAUDE.md if it does not exist
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
  cat > "$PROJECT_DIR/CLAUDE.md" << 'EOF'
# [Project Name]

[Project description]

## Knowledge Map

- `memory/MEMORY.md` -- Current state, routing table (auto-loaded)
- `memory/decisions.md` -- Decision log
- `memory/episodes/` -- Daily session logs

## Loading Instructions

- Always read `memory/MEMORY.md` at session start.
- Read topic files only when relevant to the current task.

## Preferences

- [Add preferences here]
EOF
fi

echo "Memory structure initialized at $MEMORY_DIR"
```

---

## 9. Migration Plan

### 9.1 Ordered Steps

Migration is ordered from worst-scoring to best-scoring project, so the most broken systems are fixed first and lessons learned apply to later migrations.

| Step | Action | Project | Details |
|---|---|---|---|
| **0** | **Global setup** | All | Create global `~/.claude/CLAUDE.md` with memory protocol. Update global `~/.claude/settings.json` with PreCompact and Stop hooks. |
| **1** | **Investment migration** | Investment (4/10) | Gut CLAUDE.md to ~1,000 tokens. Create `memory/MEMORY.md` index. Deduplicate M&A comps (keep one authoritative file). Deduplicate drug definitions. Resolve Exhibit A contradiction. Move deal terms and company descriptions to topic files. Add loading instructions. |
| **2** | **RFP migration** | RFP (5/10) | Merge `.claude` MEMORY.md into `memory/MEMORY.md`. Update `master-profile.md` with current engagement data and freshness header. Consolidate four workflow instances into one. Fix broken paths in `rfp-monitor-prompt.md`. |
| **3** | **RWE migration** | RWE (6.5/10) | Merge `~/.claude/projects/` content into `memory/`. Resolve 3rd vs 5th workday contradiction with Nima. Delete shadow copies in `memory/projects/`. Slim CLAUDE.md to lean router. Make session routine conditional (demand-loaded). |
| **4** | **Quant migration** | Quant (8/10) | Create `quant_app/memory/` directory. Move 5 files from `~/.claude/projects/` into `quant_app/memory/`. Eliminate pipeline status 3-way duplication. Make STATUS.md demand-loaded. |
| **5** | **Verification** | All | For each project, verify: (a) no data loss (diff old vs new), (b) CLAUDE.md under 1,000 tokens, (c) MEMORY.md under 200 lines, (d) no duplicated facts, (e) all files have freshness headers. |
| **6** | **Cleanup** | All | Delete `~/.claude/projects/*/memory/` directories. Verify hooks fire correctly in each project. |
| **7** | **Scaffold template** | N/A | Create `claude-init` script from Section 8.3. Test on a scratch project. Document in global CLAUDE.md. |

### 9.2 Risk Mitigation

| Risk | Mitigation |
|---|---|
| Data loss during migration | Before migrating each project, create a backup: `cp -r ~/.claude/projects/[project] ~/.claude/projects/[project].bak` |
| Broken references | After migration, grep for old paths (`~/.claude/projects/`) in all project files and update them. |
| Contradictions discovered during merge | Document each contradiction in `memory/decisions.md` with a "PENDING" status. Resolve with Nima before marking "RESOLVED". |
| Hook failures | Test hooks in Quant (highest-scoring project) before deploying to others. Quant is the safest test bed because it has the most robust existing structure. |

---

## 10. Appendix: OpenClaw Reference

### 10.1 Hybrid Search Configuration

OpenClaw's retrieval configuration from its source code:

```yaml
search:
  vectorWeight: 0.3
  textWeight: 0.7
  mmr:
    enabled: true
    lambda: 0.7
    fetchMultiplier: 3
  temporalDecay:
    enabled: true
    halfLifeDays: 30
    referenceTime: "now"
    evergreen:
      - "MEMORY.md"
      - "decisions.md"
```

The `fetchMultiplier: 3` means the system retrieves 3x the requested results, then MMR re-ranks and trims to the requested count. This ensures diversity in the final result set.

### 10.2 PreCompact memoryFlush Configuration

```yaml
memoryFlush:
  trigger: "PreCompact"
  mode: "silent"  # No user-visible output
  instructions: |
    Review the current context for:
    1. Decisions made (tag: DECISION)
    2. Facts learned (tag: FACT_LEARNED)
    3. Corrections to prior beliefs (tag: CORRECTION)
    4. Action items identified (tag: ACTION_ITEM)
    5. User preferences expressed (tag: PREFERENCE)
    Write tagged entries to memory/episodes/YYYY-MM-DD.md.
    Update memory/MEMORY.md if current state changed.
  maxTokens: 1000  # Budget for the silent turn
```

### 10.3 Session-Memory Hook Details

OpenClaw's hook chain in execution order:

| Hook | Trigger | Action | Output |
|---|---|---|---|
| `onSessionStart` | New session or post-compaction | Read MEMORY.md + today's episodes | Injected into context |
| `onPreCompact` | Before context compression | Silent agentic turn to flush memories | Written to episodes/ |
| `onStop` | Session end | Final memory flush + MEMORY.md update | Written to disk |
| `onFileChange` | Watched file modified externally | Re-read modified file, update index | Updated in-memory state |

### 10.4 File Watcher Configuration

```yaml
fileWatcher:
  enabled: true
  debounceMs: 1500
  watchPaths:
    - "memory/**/*.md"
  ignorePaths:
    - "memory/episodes/archive/**"
  onFileChange:
    - action: "reindex"
      scope: "changed_file"
    - action: "notify_agent"
      message: "Memory file updated externally: {filePath}"
```

The 1.5-second debounce prevents rapid-fire reindexing when a file is being actively edited (e.g., by the user in an editor). Only the final state after editing pauses is indexed.

---

## Revision History

| Date | Change |
|---|---|
| 2026-03-11 | Initial assessment created. Audited 4 projects, established target architecture, defined migration plan. |
