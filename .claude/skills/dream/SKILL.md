---
name: dream
description: >-
  Perform memory consolidation — a reflective pass over memory files that
  synthesizes recent learnings into durable, well-organized memories so
  future sessions orient quickly. Supports two modes: "consolidate" (full
  4-phase pass) and "prune" (lighter cleanup of stale/duplicate memories).
  Use when: "dream", "consolidate memories", "clean up memories", "prune
  memories", "organize memories", or at the end of a productive session.
  Invoke with: /dream [consolidate|prune]
---

# Dream: Memory Consolidation

Perform a reflective pass over memory files. Synthesize what you've learned
recently into durable, well-organized memories so that future sessions can
orient quickly.

**Type:** Rigid workflow. Follow steps exactly.

---

## Setup

Resolve these paths before starting:

```
MEMORY_DIR = ~/.claude/projects/<project-key>/memory/
INDEX_FILE = MEMORY.md (inside MEMORY_DIR)
TRANSCRIPTS_DIR = ~/.claude/projects/<project-key>/ (JSONL files)
```

To find the actual paths:

```bash
# Memory directory — look for MEMORY.md
find ~/.claude/projects/ -name "MEMORY.md" -path "*/memory/*" 2>/dev/null
```

The project key is derived from the working directory. The transcripts are
the `.jsonl` files in the project directory (siblings of the `memory/` folder).

## Parse Arguments

Parse `$ARGUMENTS`:

- **Empty or `consolidate`** — run the full 4-phase consolidation (default)
- **`prune`** — run the lighter pruning pass only (Phase P below)

---

## Mode: Consolidate (default)

### Phase 1 — Orient

- `ls` the memory directory to see what already exists
- Read the index file (`MEMORY.md`) to understand the current state
- Skim existing topic files so you improve them rather than creating duplicates

### Phase 2 — Gather recent signal

Look for new information worth persisting. Sources in rough priority order:

1. **Existing memories that drifted** — facts that contradict something you see in
   the codebase now (check via `git log`, reading current files)
2. **Transcript search** — if you need specific context (e.g., "what feedback did
   the user give about X?"), grep the JSONL transcripts for narrow terms:
   ```bash
   grep -rn "<narrow term>" <TRANSCRIPTS_DIR>/ --include="*.jsonl" | tail -50
   ```
   Don't exhaustively read transcripts. Look only for things you already suspect matter.
3. **Git history** — recent commits may reveal decisions worth capturing:
   ```bash
   git log --oneline --since="7 days ago" | head -20
   ```

### Phase 3 — Consolidate

For each thing worth remembering, write or update a memory file at the top level
of the memory directory. Use the memory file format and type conventions from the
system prompt's auto-memory section — it's the source of truth for what to save,
how to structure it, and what NOT to save.

Focus on:

- **Merging** new signal into existing topic files rather than creating near-duplicates
- **Converting** relative dates ("yesterday", "last week") to absolute dates so
  they remain interpretable after time passes
- **Deleting** contradicted facts — if today's investigation disproves an old memory,
  fix it at the source
- **Verifying** before persisting — don't save claims about file paths or function
  names without checking they still exist

**What NOT to save** (from auto-memory rules):
- Code patterns, conventions, architecture, or file paths derivable from the code
- Git history or who-changed-what (use `git log`/`git blame`)
- Debugging solutions (the fix is in the code)
- Anything already in CLAUDE.md
- Ephemeral task details or current conversation context

### Phase 4 — Prune and index

Update `MEMORY.md` so it stays under 200 lines AND under ~25KB. It's an **index**,
not a dump — each entry should be one line under ~150 characters:
`- [Title](file.md) — one-line hook`

- Remove pointers to memories that are now stale, wrong, or superseded
- Demote verbose entries: if an index line is over ~200 chars, shorten it and
  move the detail into the topic file
- Add pointers to newly important memories
- Resolve contradictions — if two files disagree, fix the wrong one

---

## Mode: Prune

A lighter pass focused only on cleanup. No transcript reading or signal gathering.

1. `find <MEMORY_DIR> -name '*.md'` to enumerate every memory file
2. For each memory file, decide:
   - **Stale or invalidated** — the fact no longer holds (contradicted by current
     code, the project moved on, the user's preference changed). Delete the file.
   - **Duplicate or near-duplicate** — another memory already covers the same fact.
     Delete the redundant copies. If a single richer memory would replace the cluster,
     delete the cluster and write one fresh file using the auto-memory format.
   - **Still good** — leave it alone.
3. Update `MEMORY.md` index to reflect any deletions.

---

## Output

Return a brief summary of what you consolidated, updated, or pruned.
If nothing changed (memories are already tight), say so.

```markdown
# Dream Summary

**Mode:** [consolidate|prune]
**Memories added:** N
**Memories updated:** N
**Memories deleted:** N
**Index entries changed:** N

## Changes
- [list each change with rationale]
```

---

## Rules

- **Never write memory content directly into MEMORY.md.** It's an index only.
- **Never save ephemeral task details.** Only persist what future sessions need.
- **Verify before persisting.** If a memory names a file or function, check it exists.
- **Merge, don't duplicate.** Check existing memories before creating new ones.
- **Convert relative dates.** "Yesterday" becomes "2026-04-11" so the memory ages well.
- **Be conservative with deletions.** A slightly stale memory costs less than deleting
  something the user relies on. When unsure, leave it.
- **Don't grep transcripts exhaustively.** Narrow searches only, for things you already
  suspect matter. Transcripts are large JSONL files.
