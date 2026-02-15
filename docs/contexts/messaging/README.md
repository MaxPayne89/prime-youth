# Context: Messaging

> The Messaging context enables communication between providers and parents. It supports direct 1-on-1 conversations and program broadcast announcements to all enrolled parents. Messages are delivered in real-time via PubSub, with a full lifecycle from creation through archival and retention-based deletion.

## What This Context Owns

- **Domain Concepts:** Conversation (direct or program broadcast), Message (text or system), Participant (membership + read receipts)
- **Data:** `conversations` table, `messages` table, `conversation_participants` table
- **Processes:** Direct messaging, program broadcasts, read tracking, conversation archival, data retention enforcement, GDPR data anonymization, real-time PubSub notifications

## Key Features

| Feature | Status | Doc |
|---|---|---|
| Direct Conversations | Active | — |
| Program Broadcasts | Active | — |
| Send Messages | Active | — |
| Read Receipts | Active | — |
| Unread Count | Active | — |
| Conversation Listing | Active | — |
| Real-time Updates (PubSub) | Active | — |
| Conversation Archival | Active | — |
| Retention Policy Enforcement | Active | — |
| GDPR Data Anonymization | Active | — |
| Entitlement Checks | Active | — |

## Inbound Communication

| From Context | Event / Call | What It Triggers |
|---|---|---|
| Accounts | `user_anonymized` integration event | Anonymizes all user messages (content → `"[deleted]"`) and marks all participations as left; publishes `message_data_anonymized` |
| Enrollment | `ForQueryingEnrollments` port | Queries enrolled parent user IDs for program broadcasts |
| Accounts | `ForResolvingUsers` port | Resolves user display names for conversation listings and message display |
| Entitlements | `Entitlements.can_initiate_messaging?/1` | Gates conversation creation and broadcast sending based on subscription tier |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| Any (via PubSub) | `message_data_anonymized` integration event | Confirms messaging data anonymization is complete (GDPR cascade) |
| LiveViews (internal) | `message_sent` via `"conversation:{id}"` topic | Real-time message delivery to open conversation views |
| LiveViews (internal) | `messages_read` via `"conversation:{id}"` topic | Real-time read receipt updates |
| LiveViews (internal) | `broadcast_sent` via `"conversation:{id}"` topic | Real-time broadcast delivery |
| LiveViews (internal) | `conversation_created` via `"user:{id}:messages"` topic | New conversation notification (fan-out to all participants) |

## Ubiquitous Language

| Term | Meaning |
|---|---|
| Direct Conversation | A private 1-on-1 conversation between a provider and a parent |
| Program Broadcast | An announcement from a provider to all parents enrolled in a specific program |
| Participant | A user who is part of a conversation, with tracking of when they joined, left, and last read |
| Read Receipt | The timestamp of when a participant last viewed messages in a conversation (`last_read_at`) |
| Unread Count | Number of messages in a conversation inserted after a participant's `last_read_at` |
| Archived | A conversation that has been soft-closed (e.g., program ended) with a retention deadline |
| Retention Period | The time window (default 30 days) after archival during which data is preserved before permanent deletion |
| System Message | An auto-generated message (e.g., "User joined conversation") vs. a regular `:text` message |
| Entitlement | A subscription-tier-based permission check; free-tier parents cannot initiate conversations but can receive and reply |

## Business Decisions

- **Two conversation types.** `:direct` for 1-on-1 provider-parent messaging. `:program_broadcast` for announcements to all enrolled parents of a program.
- **Idempotent conversation creation.** Creating a direct conversation returns the existing one if it already exists. Broadcast conversations are deduplicated per program.
- **Entitlement-gated initiation.** Free-tier parents cannot start conversations but can receive and reply. Checked via `Entitlements.can_initiate_messaging?/1`.
- **Sender auto-marks as read.** When a user sends a message, their `last_read_at` is automatically updated — they've seen what they sent.
- **Participant access control.** Only participants can send messages or view a conversation. Non-participants get `{:error, :not_participant}`.
- **Message content max 10,000 characters.** Validated at the domain model level.
- **Messages are trimmed on send.** `String.trim/1` is applied to content before persistence.
- **Soft delete for messages.** Messages have a `deleted_at` field; no hard deletes via user action.
- **Archival lifecycle.** Active → Archived (with `retention_until` set to archived_at + 30 days) → Hard deleted after retention period expires.
- **Automated archival.** An Oban worker runs daily at 3 AM to archive broadcast conversations for programs that ended 30+ days ago.
- **Automated retention cleanup.** An Oban worker runs daily at 4 AM (after archival) to permanently delete messages and conversations past their retention deadline.
- **Optimistic locking.** Conversations use `lock_version` for concurrent update protection.
- **GDPR anonymization is transactional.** Message anonymization and participation removal run in a single database transaction; partial anonymization cannot occur.
- **GDPR anonymization replaces content with `"[deleted]"`.** Does not delete rows — preserves conversation structure.
- **Real-time updates are best-effort.** PubSub publish failures are logged but swallowed; the database transaction is the source of truth.
- **Retry with backoff for cross-context event handling.** The `user_anonymized` event handler uses `RetryHelpers` for transient failure resilience.

## Assumptions & Open Questions

- [NEEDS INPUT] Should direct conversations between provider and parent also be auto-archived when the parent's last enrollment with that provider ends?
- [NEEDS INPUT] Is 30 days the correct retention period after archival, or should this be configurable per provider?
- [NEEDS INPUT] Should there be a message edit capability, or is the current send-only model intentional?
- [NEEDS INPUT] Should the `message_sent` event also fan out to `"user:{id}:messages"` for all participants (not just the conversation topic) to support global unread badge updates without polling?

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
