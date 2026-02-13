# Context Map

High-level view of all bounded contexts and how they relate to each other.

```mermaid
flowchart TB
    subgraph Core["Core Domain"]
        PC[Program Catalog]
        EN[Enrollment]
    end

    subgraph Supporting["Supporting Domain"]
        FA[Family]
        PR[Provider]
        PA[Participation]
        MS[Messaging]
    end

    subgraph Generic["Generic Domain"]
        AC[Accounts]
        SH[Shared]
    end

    %% Accounts publishes events consumed by Family and Provider
    AC -- "user_registered\nuser_anonymized" --> FA
    AC -- "user_registered\nuser_anonymized" --> PR

    %% Family publishes events consumed by Participation
    FA -- "child_data_anonymized" --> PA

    %% Accounts publishes events consumed by Messaging
    AC -- "user_anonymized" --> MS

    %% Messaging queries Enrollment for permission checks
    MS -. "queries enrolled users" .-> EN

    %% Messaging queries Program Catalog for retention
    MS -. "queries ended programs" .-> PC

    %% Enrollment depends on Program Catalog for program data
    EN -. "references programs" .-> PC

    %% Participation tracks sessions for programs
    PA -. "references programs\n& children" .-> PC
    PA -. "references children" .-> FA

    %% Shared provides infrastructure to all
    SH -. "event bus, helpers" .-> AC
    SH -. "event bus, helpers" .-> FA
    SH -. "event bus, helpers" .-> PR
    SH -. "event bus, helpers" .-> PC
    SH -. "event bus, helpers" .-> EN
    SH -. "event bus, helpers" .-> MS
    SH -. "event bus, helpers" .-> PA
```

## Legend

- **Solid arrows** = integration events (async, event-driven communication)
- **Dashed arrows** = direct queries or references (sync, through ports)

## Context Summary

| Context | Type | Purpose |
|---|---|---|
| **Accounts** | Generic | User auth, registration, tokens, sessions |
| **Family** | Supporting | Parent profiles, children, consents, referral codes |
| **Provider** | Supporting | Provider profiles, staff, verification documents |
| **Program Catalog** | Core | Program discovery, categories, pricing, availability |
| **Enrollment** | Core | Bookings, fee calculations, subscription tiers |
| **Messaging** | Supporting | Conversations, messages, participants, retention |
| **Participation** | Supporting | Session tracking, check-in/out, attendance |
| **Shared** | Generic | Event bus, domain event publishing, Ecto helpers |

## Key Integration Events

| Event | Published By | Consumed By | Purpose |
|---|---|---|---|
| `user_registered` | Accounts | Family, Provider | Create parent/provider profiles on registration |
| `user_anonymized` | Accounts | Family, Provider, Messaging | GDPR data cleanup across contexts |
| `child_data_anonymized` | Family | Participation | Anonymize child attendance records |
