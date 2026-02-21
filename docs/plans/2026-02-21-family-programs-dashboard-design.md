# Family Programs Section — Parent Dashboard (#154)

## Overview

Add "Family Programs" section to `DashboardLive` below "Family Achievements". Displays parent's enrolled programs as cards. No new backend work — uses existing `ListParentEnrollments` and `GetProgramById`.

## Data Loading

In `DashboardLive.mount/3`:

- `ListParentEnrollments.execute(parent_id)` → get enrollments
- `GetProgramById.execute(program_id)` → full program for each enrollment
- Split into **active** and **expired** lists
- Active sorted by next session date ascending; expired by end date descending
- Assign both to socket

## Component Changes

Extend `<.program_card>` with optional attrs:

- `session_info` — date range + session times display
- `contact_url` — renders "Contact" button linking to `/messages`
- `expired` (boolean) — greyed-out styling (opacity, muted colors)

## Template Structure

```
[Family Achievements — existing]

[Family Programs — NEW]
  ├── Header: "Family Programs"
  ├── Empty state → "Book a Program" button → /programs
  ├── Active cards (upcoming session, soonest first)
  └── Expired cards (greyed out, at bottom)
```

## Expired Detection

Program is expired if **either**:

- Enrollment status is `completed` or `cancelled`
- Program's last session date is in the past

## Contact Button

Links to `/messages` (general inbox). Provider-specific conversation routing deferred.

## Out of Scope

- New backend use cases or ports
- Provider-specific messaging flow
- Pagination
- Real-time updates via PubSub
