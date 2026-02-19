# Context: Enrollment

> Enrollment manages program bookings for children, capacity constraints, and participant eligibility restrictions. A parent selects a program for their child, the system validates their subscription tier, checks program capacity, verifies the child meets participant restrictions (age, gender, grade), calculates fees, and creates the enrollment. Providers set enrollment policies (min/max capacity) and participant policies (eligibility criteria) per program. This context also provides enrollment data to other contexts like Messaging (for broadcast targeting), ProgramCatalog (for requirements display), and Entitlements (for usage tracking).

## What This Context Owns

- **Domain Concepts:** Enrollment (aggregate root), EnrollmentPolicy (capacity constraints), ParticipantPolicy (eligibility restrictions), FeeCalculation (value object), enrollment statuses, payment methods
- **Data:** `enrollments` table (program/child/parent linkage, status lifecycle, fee amounts, special requirements), `enrollment_policies` table (per-program min/max capacity), `participant_policies` table (per-program age/gender/grade restrictions)
- **Processes:** Enrollment creation with entitlement + capacity + eligibility validation, fee calculation, booking usage tracking, enrollment status lifecycle (pending -> confirmed -> completed / cancelled), enrollment policy management (set/query capacity per program), participant policy management (set/query eligibility per program)

## Key Features

| Feature | Status | Doc |
|---|---|---|
| Create Enrollment | Active | - |
| Enrollment Capacity (Policies) | Active | [capacity](features/capacity.md) |
| Participant Restrictions | Active | [participant-restrictions](features/participant-restrictions.md) |
| Fee Calculation | Active | - |
| Booking Usage Tracking | Active | - |
| Enrollment Status Lifecycle | Active | - |
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
| ProgramCatalog | Subscribes to `integration:enrollment:participant_policy_set` | Caches participant restrictions for program detail display |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| Family | `Family.get_parent_by_identity/1` | Resolves parent profile from identity ID |
| Family | `Family.get_child_by_id/1` (via ParticipantDetailsACL) | Resolves child date_of_birth, gender, school_grade for eligibility checks |
| Entitlements | `Entitlements.can_create_booking?/2` | Validates booking against subscription tier cap |
| Entitlements | `Entitlements.monthly_booking_cap/1` | Retrieves monthly booking cap for a parent's tier |
| ProgramCatalog | Direct DB query (via ProgramScheduleACL) | Resolves program start_date for "at program start" eligibility checks |
| ProgramCatalog | `participant_policy_set` integration event | Notifies ProgramCatalog when restrictions change (for cache invalidation / display) |

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

## Assumptions & Open Questions

- [NEEDS INPUT] What happens to enrollments when a program is cancelled or deleted? No cascade or compensation logic exists yet.
- [NEEDS INPUT] Can a parent cancel a confirmed enrollment at any time, or are there time-based restrictions?
- [NEEDS INPUT] Are there refund implications when an enrollment is cancelled? Fee calculation exists but no refund logic.
- [NEEDS INPUT] The fee calculation doesn't account for discounts, promo codes, or sibling discounts. Is this planned?
- [NEEDS INPUT] Should reaching min_enrollment trigger a notification to the provider? Currently `meets_minimum?/2` exists as a domain check but nothing consumes it.
- [NEEDS INPUT] Should existing enrollments be re-validated when a participant policy is changed? Currently, policy changes only affect future eligibility checks.
- [NEEDS INPUT] Should the "not_specified" gender be treated as "matches all policies" or "matches only when explicitly allowed"?

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
