# Fix #299: Duplicate Child on Parent Profile

## Problem

When a provider uploads the same child to multiple programs via CSV import, each
invite claim creates a separate child record. The `InviteClaimedHandler` has a
`find_existing_child` check, but concurrent `invite_claimed` events race through
it (TOCTOU) — both see `nil`, both create. No DB uniqueness constraint prevents
this.

Result: the parent dashboard shows the same child multiple times.

## Root Cause

1. `InviteClaimedHandler` processes `invite_claimed` events synchronously
2. Two events for the same parent can execute concurrently
3. `find_existing_child` does an in-memory scan (not atomic with the insert)
4. `children` table has no uniqueness constraint scoped to a guardian

## Prevention: Oban-Serialized Use Case

### Architecture (ports & adapters)

```
InviteClaimedHandler (integration event handler)
  -- enqueues job, thin adapter --
      |
ProcessInviteClaimWorker (driven adapter, Oban worker)
  -- deserializes args, calls use case, thin adapter --
      |
ProcessInviteClaim (use case)
  -- ensure parent, find-or-create child, publish invite_family_ready --
  -- uses ForStoringChildren, ForStoringParentProfiles ports --
```

### Serialization

Oban `unique: [keys: [:parent_id], period: 60]` ensures only one job per parent
runs at a time. Concurrent invite claims for the same parent queue up instead of
racing.

### Key files

| Layer | File | Role |
|---|---|---|
| Event handler | `family/adapters/driven/events/invite_claimed_handler.ex` | Becomes thin: enqueue Oban job |
| Oban worker | `family/adapters/driven/workers/process_invite_claim_worker.ex` | Thin: deserialize args, call use case |
| Use case | `family/application/use_cases/invites/process_invite_claim.ex` | Owns orchestration logic (moved from handler) |

### Logic (unchanged, just relocated to use case)

1. `ensure_parent_profile(user_id)` — create or fetch
2. `find_existing_child(parent_id, first_name, last_name, dob)` — scan parent's children
3. If nil, `create_child(attrs)` with guardian link
4. `publish_family_ready(invite_id, child_id, parent_id, program_id)`

## Remediation: Merge Existing Duplicates

One-off Elixir script at `priv/repo/scripts/remediate_duplicate_children.exs`.
Run via `fly ssh console` with `rpc`.

### Algorithm

1. Identify duplicate groups: query `children_guardians` joined with `children`,
   group by `(guardian_id, lower(first_name), lower(last_name), date_of_birth)`,
   filter groups with count > 1.

2. For each group, pick oldest child (`min(inserted_at)`) as survivor.

3. Merge non-null fields from duplicates into survivor (COALESCE-style):
   `emergency_contact`, `support_needs`, `allergies`, `school_name`, `school_grade`.

4. Re-point all references from duplicate to survivor (skip on conflict):
   - `enrollments` — skip if survivor already enrolled in that program
   - `consents` — skip if active consent of same type exists on survivor
   - `participation_records` — skip if same session exists for survivor
   - `behavioral_notes` — re-point unconditionally
   - `children_guardians` — delete duplicate's link (survivor's link exists)

5. Delete duplicate child record.

6. Each group wrapped in its own transaction.

7. Dry-run mode first (log-only), then execute.

## Testing

| Test | Scope |
|---|---|
| `ProcessInviteClaim` use case | find-or-create: first call creates, second returns existing |
| `ProcessInviteClaimWorker` | Job enqueued with correct args, unique key on `[:parent_id]` |
| `InviteClaimedHandler` | Enqueues job instead of doing work directly |

Remediation script: dry-run mode serves as safety net, no formal test file.
