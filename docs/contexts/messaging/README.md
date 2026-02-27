# Context: Messaging

> The Messaging context enables communication between providers and parents. It supports direct 1-on-1 conversations and program broadcast announcements to all enrolled parents. Messages are delivered in real-time via PubSub, with a full lifecycle from creation through archival and retention-based deletion.

## What This Context Owns

- **Domain Concepts:** Conversation (direct or program broadcast), Message (text or system), Participant (membership + read receipts), ConversationSummary (CQRS read DTO)
- **Data:**
  - `conversations` table (write model — type, provider_id, program_id, subject, archived_at, retention_until, lock_version)
  - `messages` table (write model — conversation_id, sender_id, content, message_type, deleted_at)
  - `conversation_participants` table (write model — conversation_id, user_id, joined_at, left_at, last_read_at)
  - `conversation_summaries` table (read model — denormalized per-user inbox rows with latest message, unread count, other participant name)
- **Processes:** Direct messaging, program broadcasts, read tracking, CQRS projection (ConversationSummaries GenServer), conversation archival (Oban daily 3 AM), retention enforcement (Oban daily 4 AM), GDPR data anonymization, real-time PubSub notifications

## Key Features

| Feature | Status | Doc |
|---|---|---|
| Direct Conversations | Active | — |
| Program Broadcasts | Active | — |
| Send Messages | Active | — |
| Read Receipts | Active | — |
| Unread Count | Active | — |
| Conversation Listing (CQRS read model) | Active | — |
| CQRS Conversation Summaries Projection | Active | — |
| Real-time Updates (PubSub) | Active | — |
| Conversation Archival | Active | — |
| Retention Policy Enforcement | Active | — |
| GDPR Data Anonymization | Active | — |
| Entitlement Checks | Active | — |

## Inbound Communication

| From Context | Event / Call | What It Triggers |
|---|---|---|
| Accounts | `user_anonymized` integration event | Anonymizes all user messages (content -> `"[deleted]"`) and marks all participations as left; publishes `message_data_anonymized` |
| Enrollment | `ForQueryingEnrollments` port | Queries enrolled parent user IDs for program broadcasts |
| Accounts | `ForResolvingUsers` port | Resolves user display names for conversation listings, message display, and projection bootstrap |
| Entitlements | `Entitlements.can_initiate_messaging?/1` | Gates conversation creation and broadcast sending based on subscription tier |
| Program Catalog | `ProgramCatalog.list_ended_program_ids/1` (cross-context query) | Called by the archival worker to find programs that have ended, so their broadcast conversations can be archived |
| Self (integration events) | `conversation_created`, `message_sent`, `messages_read`, `conversation_archived`, `conversations_archived`, `message_data_anonymized` | ConversationSummaries projection subscribes to its own integration events to maintain the read model |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| Any subscriber | `integration:messaging:conversation_created` | Notifies that a new conversation was created (payload: conversation_id, participant_ids, provider_id) |
| Any subscriber | `integration:messaging:message_sent` | Notifies that a message was sent (payload: conversation_id, sender_id, content) |
| Any subscriber | `integration:messaging:messages_read` | Notifies that messages were read (payload: conversation_id, user_id) |
| Any subscriber | `integration:messaging:conversation_archived` | Notifies that a conversation was archived (payload: conversation_id) |
| Any subscriber | `integration:messaging:conversations_archived` | Notifies bulk archival (payload: conversation_ids) |
| Any subscriber | `integration:messaging:message_data_anonymized` | Confirms messaging data anonymization is complete (GDPR cascade, criticality: critical) |
| LiveViews (internal) | `message_sent` via `"conversation:{id}"` topic | Real-time message delivery to open conversation views |
| LiveViews (internal) | `messages_read` via `"conversation:{id}"` topic | Real-time read receipt updates |
| LiveViews (internal) | `broadcast_sent` via `"conversation:{id}"` topic | Real-time broadcast delivery |
| LiveViews (internal) | `conversation_created` via `"user:{id}:messages"` topic | New conversation notification (fan-out to all participants) |

## Ubiquitous Language

| Term | Meaning |
|---|---|
| **Direct Conversation** | A private 1-on-1 conversation between a provider and a parent |
| **Program Broadcast** | An announcement from a provider to all parents enrolled in a specific program |
| **Participant** | A user who is part of a conversation, with tracking of when they joined, left, and last read |
| **Read Receipt** | The timestamp of when a participant last viewed messages in a conversation (`last_read_at`) |
| **Unread Count** | Number of messages in a conversation inserted after a participant's `last_read_at` |
| **Conversation Summary** | A denormalized, per-user inbox row from the CQRS read model. Contains latest message, unread count, other participant name — optimized for list display without joins |
| **Archived** | A conversation that has been soft-closed (e.g., program ended) with a retention deadline |
| **Retention Period** | The time window (default 30 days) after archival during which data is preserved before permanent deletion |
| **System Message** | An auto-generated message (e.g., "User joined conversation") vs. a regular `:text` message |
| **Entitlement** | A subscription-tier-based permission check; free-tier parents cannot initiate conversations but can receive and reply |
| **Projection** | A GenServer that subscribes to integration events and maintains the `conversation_summaries` read table in sync with the write model |

## Business Decisions

- **Two conversation types.** `:direct` for 1-on-1 provider-parent messaging. `:program_broadcast` for announcements to all enrolled parents of a program.
- **CQRS with separate read/write models.** Write tables (`conversations`, `messages`, `conversation_participants`) are the source of truth. The `conversation_summaries` read table is a denormalized projection with one row per user per conversation, maintained by the ConversationSummaries GenServer. This avoids expensive multi-table joins for inbox listing.
- **Projection subscribes to its own integration events.** The ConversationSummaries projection listens to Messaging's own integration events (not domain events), ensuring it processes the same stable contract that external subscribers see.
- **Projection subscribes before bootstrapping.** On startup, the GenServer subscribes to all PubSub topics before loading existing data from write tables. This prevents missing events that arrive between bootstrap and subscription.
- **Bootstrap resolves display names in bulk.** The projection fetches all user display names via `ForResolvingUsers` during bootstrap to populate `other_participant_name`, avoiding N+1 queries.
- **Bootstrap retries with backoff.** Up to 3 retries with 5s x retry_count exponential backoff. After exhausting retries, the GenServer crashes to let the supervisor restart it.
- **Idempotent conversation creation.** Creating a direct conversation returns the existing one if it already exists. Broadcast conversations are deduplicated per program via a unique constraint.
- **Entitlement-gated initiation.** Free-tier parents cannot start conversations but can receive and reply. Checked via `Entitlements.can_initiate_messaging?/1`.
- **Sender auto-marks as read.** When a user sends a message, their `last_read_at` is automatically updated — they've seen what they sent.
- **Participant access control.** Only participants can send messages or view a conversation. Non-participants get `{:error, :not_participant}`.
- **Message content max 10,000 characters.** Validated at the domain model level. Content is trimmed on send.
- **Soft delete for messages.** Messages have a `deleted_at` field; no hard deletes via user action.
- **Archival lifecycle.** Active -> Archived (with `retention_until` set to archived_at + 30 days) -> Hard deleted after retention period expires.
- **Automated archival.** An Oban worker (`MessageCleanupWorker`) runs daily at 3 AM to archive broadcast conversations for programs that ended 30+ days ago.
- **Automated retention cleanup.** An Oban worker (`RetentionPolicyWorker`) runs daily at 4 AM (after archival) to permanently delete messages and conversations past their retention deadline.
- **Optimistic locking.** Conversations use `lock_version` for concurrent update protection.
- **GDPR anonymization is transactional.** Message anonymization and participation removal run in a single database transaction; partial anonymization cannot occur.
- **GDPR anonymization replaces content with `"[deleted]"`.** Does not delete rows — preserves conversation structure. The projection updates `other_participant_name` to `"Deleted User"`.
- **Integration event criticality varies.** `conversation_created` and `message_sent` promotions propagate errors back to the use case (critical path). `messages_read`, `conversation_archived`, `conversations_archived` are best-effort (swallow failures). `message_data_anonymized` is marked as GDPR-critical.
- **Real-time updates are best-effort.** PubSub publish failures are logged but swallowed; the database transaction is the source of truth.
- **Retry with backoff for cross-context event handling.** The `user_anonymized` event handler uses `RetryHelpers` (100ms backoff) for transient failure resilience.

## Assumptions & Open Questions

- [NEEDS INPUT] Should direct conversations between provider and parent also be auto-archived when the parent's last enrollment with that provider ends?
- [NEEDS INPUT] Is 30 days the correct retention period after archival, or should this be configurable per provider?
- [NEEDS INPUT] Should there be a message edit capability, or is the current send-only model intentional?
- [NEEDS INPUT] Should the `message_sent` event also fan out to `"user:{id}:messages"` for all participants (not just the conversation topic) to support global unread badge updates without polling?

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
