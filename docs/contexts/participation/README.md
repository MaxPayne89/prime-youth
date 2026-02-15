# Context: Participation

> Participation tracks what happens during program sessions: scheduling sessions, recording child check-ins and check-outs, marking absences, and capturing provider observations (behavioral notes) about each child. It serves both providers running sessions in real-time and parents reviewing their child's attendance and feedback.

## What This Context Owns

- **Domain Concepts:** ProgramSession (session lifecycle), ParticipationRecord (attendance tracking), BehavioralNote (provider observations with parent approval), ParticipationCollection (collection-level operations)
- **Data:** `program_sessions` table, `participation_records` table, `behavioral_notes` table
- **Processes:** Session lifecycle (scheduled -> in-progress -> completed), check-in/check-out flow, behavioral note approval workflow, GDPR anonymization of notes, real-time LiveView updates via PubSub

## Key Features

| Feature | Status | Doc |
|---|---|---|
| Session Management | Active | - |
| Check-In / Check-Out | Active | - |
| Bulk Check-In | Active | - |
| Behavioral Notes (submit/review/revise) | Active | - |
| Session Roster with Child Info | Active | - |
| Participation History | Active | - |
| GDPR Anonymization | Active | - |
| Real-Time LiveView Updates | Active | - |

## Inbound Communication

| From Context | Event / Call | What It Triggers |
|---|---|---|
| Family | `:child_data_anonymized` integration event | Anonymizes all behavioral notes for the deleted child |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| Family | `ForResolvingChildInfo` port (anti-corruption layer) | Resolves child name, allergies, support needs, emergency contact. Gated by `"provider_data_sharing"` consent. |
| Shared | `DomainEventBus.publish/1` | Publishes all domain events (session lifecycle, check-in/out, behavioral notes) |

## Ubiquitous Language

| Term | Meaning |
|---|---|
| Program Session | A scheduled occurrence of a program on a specific date and time. Has a lifecycle: scheduled -> in-progress -> completed (or cancelled). |
| Participation Record | Tracks one child's attendance at one session. Starts as "registered", transitions to "checked in" then "checked out" (or "absent"). |
| Check-In | The moment a child arrives at a session. Recorded by the provider with an optional note. |
| Check-Out | The moment a child leaves a session. Recorded by the provider with an optional note. |
| Absent | A child who was registered but never checked in when the session completes. Marked automatically. |
| Behavioral Note | A provider's written observation about a child during a session. Requires parent approval before becoming visible. Max 1000 characters. |
| Pending Approval | A behavioral note waiting for the parent to approve or reject it. |
| Revision | When a parent rejects a note, the provider can revise the content and resubmit for approval. |
| Roster | The list of children registered/attending a session, enriched with their safety info (allergies, support needs, emergency contact). |
| Consent Gate | Child safety info and behavioral notes are only shown to providers when the parent has an active `"provider_data_sharing"` consent. |
| Lock Version | Optimistic locking field on sessions and records. Prevents concurrent updates from silently overwriting each other. |

## Business Decisions

- **Session completion auto-marks absences.** When a provider completes a session, all children still in "registered" status are automatically marked absent. This ensures every child has a final attendance status.
- **One record per child per session.** Enforced by a unique DB constraint on `(session_id, child_id)`. Prevents double-registration.
- **One behavioral note per provider per record.** A provider can only write one note per child per session. Enforced by unique constraint on `(participation_record_id, provider_id)`.
- **Behavioral notes require parent approval.** Notes go through a pending -> approved/rejected workflow. Parents control what goes on record about their child.
- **Rejected notes can be revised.** Providers can edit and resubmit rejected notes. Revision clears the rejection reason and resets to pending.
- **Child safety info is consent-gated.** Allergies, support needs, and emergency contacts are only shown on the roster when the parent has active `"provider_data_sharing"` consent. Without consent, these fields return nil.
- **Optimistic locking prevents concurrent conflicts.** Sessions and participation records use `lock_version` to detect stale updates. Returns `:stale_data` error if another update happened first.
- **GDPR anonymization replaces content.** When a child account is deleted, all their behavioral notes have content replaced with `"[Removed - account deleted]"` and status set to `:rejected` to exclude them from active views.
- **No duplicate sessions at same program/date/time.** Unique constraint on `(program_id, session_date, start_time)`.
- **Session time range validated.** `end_time` must be after `start_time`. Checked at domain model level.
- **Behavioral notes only for attended children.** Notes can only be submitted for records in `checked_in` or `checked_out` status. Cannot write notes about absent or registered-only children.

## Assumptions & Open Questions

- [NEEDS INPUT] Provider filtering for `list_by_provider_and_date` is simplified (TODO in code). How should provider-to-program association work?
- [NEEDS INPUT] Can a session be rescheduled or its time changed after creation? Currently only status, location, notes, and max_capacity can be updated.
- [NEEDS INPUT] Is there a maximum number of behavioral notes a provider can submit across all children in a session?
- [NEEDS INPUT] Should parents receive a notification when a behavioral note is submitted for their child? Events are published but no notification handling exists yet.
- [NEEDS INPUT] What happens to participation records when a session is cancelled? Currently only session status changes, records remain.
- [NEEDS INPUT] Should there be a time limit for submitting behavioral notes after a session completes?

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
