# Context: Enrollment

> Enrollment manages program bookings for children, capacity constraints, and participant eligibility restrictions. A parent selects a program for their child, the system validates their subscription tier, checks program capacity, verifies the child meets participant restrictions (age, gender, grade), calculates fees, and creates the enrollment. Providers set enrollment policies (min/max capacity) and participant policies (eligibility criteria) per program. This context also provides enrollment data to other contexts like Messaging (for broadcast targeting), ProgramCatalog (for requirements display), and Entitlements (for usage tracking).

## What This Context Owns

- **Domain Concepts:** Enrollment (aggregate root), EnrollmentPolicy (capacity constraints), ParticipantPolicy (eligibility restrictions), FeeCalculation (value object), enrollment statuses, payment methods
- **Data:** `enrollments` table (program/child/parent linkage, status lifecycle, fee amounts, special requirements), `enrollment_policies` table (per-program min/max capacity), `participant_policies` table (per-program age/gender/grade restrictions), `bulk_enrollment_invites` table (CSV-imported invites with guardian/child/program data and invite lifecycle)
- **Processes:** Enrollment creation with entitlement + capacity + eligibility validation, fee calculation, booking usage tracking, enrollment status lifecycle (pending -> confirmed -> completed / cancelled), enrollment policy management (set/query capacity per program), participant policy management (set/query eligibility per program), bulk CSV import of enrollment invites, invite email pipeline (token generation → Oban job enqueueing → email delivery → status transitions)

## Key Features

| Feature | Status | Doc |
|---|---|---|
| Create Enrollment | Active | - |
| Enrollment Capacity (Policies) | Active | [capacity](features/capacity.md) |
| Participant Restrictions | Active | [participant-restrictions](features/participant-restrictions.md) |
| Fee Calculation | Active | - |
| Booking Usage Tracking | Active | - |
| Enrollment Status Lifecycle | Active | - |
| CSV Bulk Import | Active | [import-enrollment-csv](features/import-enrollment-csv.md) |
| Invite Email Pipeline | Active | [invite-email-pipeline](features/invite-email-pipeline.md) |
| Invite Claim Saga | Active | - |
| Cross-Context Enrollment Queries | Active | - |

## Inbound Communication

| From Context | Event / Call | What It Triggers |
|---|---|---|
| Messaging | `Enrollment.list_enrolled_identity_ids/1` | Returns identity IDs with active enrollments in a program (for broadcast targeting) |
| Messaging | `Enrollment.enrolled?/2` | Checks if a user has an active enrollment in a program |
| Entitlements | `Enrollment.count_monthly_bookings/2` | Returns active enrollment count for a parent in a given month |
| Provider (Web) | `Enrollment.set_enrollment_policy/1` | Provider sets min/max capacity on a program |
| Provider (Web) | `Enrollment.get_enrollment_policy/1` | Retrieves current capacity settings for a program |
| Provider (Web) | `Enrollment.remaining_capacity/1` | Calculates remaining spots for a program |
| Provider (Web) | `Enrollment.get_remaining_capacities/1` | Batch remaining-spots calculation for program listings |
| Provider (Web) | `Enrollment.count_active_enrollments/1` | Current enrollment count for a program |
| Provider (Web) | `Enrollment.set_participant_policy/1` | Provider sets age/gender/grade restrictions on a program |
| Provider (Web) | `Enrollment.get_participant_policy/1` | Retrieves current eligibility restrictions for a program |
| Provider (Web) | `Enrollment.new_participant_policy_changeset/1` | Form validation for participant restriction fields |
| Booking (Web) | `Enrollment.check_participant_eligibility/2` | Validates child meets program restrictions before enrollment |
| Provider (Web) | `Enrollment.import_enrollment_csv/2` | Bulk CSV import of enrollment invites for a provider |
| Guardian (Web) | `Enrollment.claim_invite/1` | Claims an invite by token, creates user account, triggers registration saga |
| ProgramCatalog | Subscribes to `integration:enrollment:participant_policy_set` | Caches participant restrictions for program detail display |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| Family | `Family.get_parent_by_identity/1` | Resolves parent profile from identity ID |
| Family | `Family.get_child_by_id/1` (via ParticipantDetailsACL) | Resolves child date_of_birth, gender, school_grade for eligibility checks |
| Entitlements | `Entitlements.can_create_booking?/2` | Validates booking against subscription tier cap |
| Entitlements | `Entitlements.monthly_booking_cap/1` | Retrieves monthly booking cap for a parent's tier |
| ProgramCatalog | Direct DB query (via ProgramScheduleACL) | Resolves program start_date for "at program start" eligibility checks |
| ProgramCatalog | Direct DB query (via ProgramCatalogACL) | Resolves provider's program titles to IDs for CSV import |
| ProgramCatalog | `participant_policy_set` integration event | Notifies ProgramCatalog when restrictions change (for cache invalidation / display) |
| Family | `invite_claimed` integration event | Triggers parent profile + child creation from invite data |
| Family | `invite_family_ready` integration event (received) | Triggers enrollment creation and transitions invite to `enrolled` |
| Accounts | `Accounts.get_user_by_email/1`, `Accounts.register_user/1` | Resolves or creates user during invite claim |
| Accounts | `Accounts.generate_magic_link_token/1` | Generates passwordless login token for new users |
| Guardian (Email) | `SendInviteEmailWorker` via Resend | Sends enrollment invitation email with registration link to guardian |

## Ubiquitous Language

| Term | Meaning |
|---|---|
| Enrollment | A booking that links a child to a program, created by a parent. Has a status lifecycle. |
| Active Enrollment | An enrollment with status `pending` or `confirmed`. Used for duplicate checks, capacity counting, and broadcast targeting. |
| Enrollment Policy | Per-program capacity constraints defining minimum and/or maximum enrollment limits. One policy per program. |
| Participant Policy | Per-program eligibility restrictions defining age range, allowed genders, and grade range for participants. One policy per program. |
| Eligibility Check | Validation that a child meets a program's participant policy. Returns `:eligible` or `:ineligible` with specific failure reasons. |
| Eligibility At | When to evaluate a child's age for eligibility: at registration time (today) or at program start date. |
| Remaining Capacity | Max enrollment minus active enrollment count. Returns `:unlimited` when no policy or no max is set. |
| Fee Calculation | A breakdown of costs: subtotal (weekly + registration fee), VAT, optional card fee, and total. |
| Booking Usage | How many active enrollments a parent has in the current month vs. their subscription tier cap. |
| Payment Method | How the parent pays: `card` (incurs card fee) or `transfer` (no card fee). |
| Special Requirements | Free-text parent notes attached to an enrollment (max 500 chars). |
| Cancellation Reason | Free-text explanation when an enrollment is cancelled (max 1000 chars). |
| Bulk Enrollment Invite | A pending invite created via CSV import, linking a child to a program before the parent registers. Has its own status lifecycle: pending → invite_sent → registered → enrolled (or failed). |
| Invite Token | A cryptographically secure URL-safe token assigned to a pending invite. Used to build the registration link sent via email. Generated from 32 random bytes, Base64-encoded. |
| Invite Email Pipeline | The async flow triggered after CSV import: generate tokens → enqueue Oban jobs → deliver emails → transition invites to `invite_sent`. |
| Invite Claim Saga | The event-driven choreography triggered when a guardian clicks the invite link: `claim_invite` → `invite_claimed` event → Family creates parent/child → `invite_family_ready` event → Enrollment creates enrollment → invite transitions to `enrolled`. |
| Magic Link Token | A short-lived login token generated for newly created users during invite claiming. Allows passwordless first login; user can set a password later in settings. |
| CSV Import | Provider-initiated bulk upload of enrollment invites. Parses, validates, deduplicates, and atomically inserts all rows in a single transaction. |

## Business Decisions

- **One active enrollment per child per program.** Enforced by a unique partial DB index on `(program_id, child_id)` for active statuses. Prevents double-booking.
- **Capacity is enforced atomically.** `create_with_capacity_check` uses `SELECT FOR UPDATE` on the policy row inside a transaction, preventing TOCTOU races for concurrent enrollments. Returns `:program_full` when at capacity.
- **No policy means unlimited capacity.** Programs without an enrollment policy accept unlimited enrollments. `remaining_capacity/1` returns `{:ok, :unlimited}` when no policy exists.
- **No participant policy means all children eligible.** Programs without a participant policy accept all children. `check_participant_eligibility/2` returns `{:ok, :eligible}`.
- **One policy per program.** Enforced by a unique constraint on `program_id`. Policy upserts replace values via `ON CONFLICT ... REPLACE`.
- **Policy requires at least one bound.** Either `min_enrollment` or `max_enrollment` (or both) must be set for capacity. Participant policies are optional across all fields.
- **Participant restrictions collect all failure reasons.** Eligibility check evaluates all criteria (age, gender, grade) and returns the complete list of failures, not just the first one.
- **Eligibility can be checked at registration or program start.** `eligibility_at` field controls the reference date for age calculation. Defaults to "registration" (today).
- **Age is calculated in complete months.** Uses date arithmetic that accounts for birthday edge cases (e.g., born Feb 29).
- **Allowed genders default to empty list (all allowed).** An empty `allowed_genders` array means no gender restriction. Only populated values restrict participation.
- **Enrollment creation validates eligibility.** When `identity_id` is provided, the create flow checks participant eligibility after entitlement validation. Ineligible children are rejected before capacity check.
- **Policies cascade-delete with programs.** When a program is deleted, its enrollment and participant policies are automatically removed (`on_delete: :delete_all`).
- **Status transitions are strict.** Pending -> Confirmed -> Completed. Both Pending and Confirmed can be Cancelled. No other transitions allowed.
- **Card fees only apply to card payments.** Transfer payments have zero card fee.
- **Entitlement validation is conditional.** Only checked when `identity_id` is provided (user-facing flow). Direct `parent_id` calls skip validation (internal/admin usage).
- **Monthly booking count uses calendar months.** Counted by `enrolled_at` timestamp, from the 1st to the last day of the month, active enrollments only.
- **Infrastructure errors crash.** Repository doesn't catch DB connection failures. The supervision tree handles recovery. Only domain errors (duplicate, not found, validation) are returned as tagged tuples.
- **Integration events notify other contexts.** `participant_policy_set` is published as an integration event so ProgramCatalog can update its display of requirements.
- **CSV import is atomic.** All rows are inserted in a single transaction via `Ecto.Multi`. If any row fails, the entire import is rolled back.
- **CSV import validates all rows before persisting.** Parse errors, validation errors, and duplicates are all collected and returned as structured error maps. No partial writes.
- **Duplicate detection at two levels.** Within-CSV batch (same email + child name + program) and against existing DB records (same composite key in `bulk_enrollment_invites`).
- **CSV upload capped at 2MB.** The controller enforces a file size limit before parsing.
- **Bulk invite deduplication key.** `(program_id, guardian_email, child_first_name, child_last_name)` — case-insensitive comparison via downcased values.
- **Bulk invite status lifecycle.** `pending → invite_sent → registered → enrolled` (or `failed` from any state, `failed → pending` for retries). Transitions are validated in the schema changeset.
- **Invite email sending is event-driven.** CSV import publishes `bulk_invites_imported`, which triggers token generation and Oban job creation. The event handler is a thin adapter; domain logic lives in the `EnqueueInviteEmails` use case.
- **Token generation is idempotent.** `list_pending_without_token` only returns invites with `status = "pending" AND invite_token IS NULL`. Re-dispatching the event won't duplicate emails.
- **Email delivery retries up to 3 times.** `SendInviteEmailWorker` uses Oban's built-in retry (max 3 attempts). On permanent failure, the invite transitions to `failed` with error details.
- **Non-pending invites are skipped.** The worker checks status before sending. If an invite was already processed (retried by Oban, or event re-dispatched), it returns `:skipped` without sending.

## Assumptions & Open Questions

- [NEEDS INPUT] What happens to enrollments when a program is cancelled or deleted? No cascade or compensation logic exists yet.
- [NEEDS INPUT] Can a parent cancel a confirmed enrollment at any time, or are there time-based restrictions?
- [NEEDS INPUT] Are there refund implications when an enrollment is cancelled? Fee calculation exists but no refund logic.
- [NEEDS INPUT] The fee calculation doesn't account for discounts, promo codes, or sibling discounts. Is this planned?
- [NEEDS INPUT] Should reaching min_enrollment trigger a notification to the provider? Currently `meets_minimum?/2` exists as a domain check but nothing consumes it.
- [NEEDS INPUT] Should existing enrollments be re-validated when a participant policy is changed? Currently, policy changes only affect future eligibility checks.
- [NEEDS INPUT] Should the "not_specified" gender be treated as "matches all policies" or "matches only when explicitly allowed"?
- ~~Should bulk enrollment invites trigger actual invitation emails?~~ **Resolved.** Invite emails are now sent via Resend after CSV import. The `bulk_invites_imported` event triggers token generation and Oban job enqueueing.
- ~~What happens after a parent registers from a bulk invite?~~ **Resolved.** The Invite Claim Saga handles this: `GET /invites/:token` triggers `claim_invite/1`, which creates/resolves the user and publishes `invite_claimed`. Family creates parent+child, then publishes `invite_family_ready`. Enrollment creates the enrollment and transitions the invite to `enrolled`. New users are auto-logged-in via magic link token.
- [NEEDS INPUT] Should large CSV imports (e.g., 10k+ rows) use chunked transactions instead of a single transaction?

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
