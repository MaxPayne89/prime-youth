# Program Scheduling Fields Design

**Issue:** GH #146 — Add program scheduling fields to provider "Add Programs" section
**Date:** 2026-02-15
**Beads:** prime-youth-0ax

## Problem

Programs have a single `schedule` string field ("Wednesdays 4-6 PM") with no structure. Providers cannot set meeting days, times, or date ranges through the form. Downstream features (#154 Family Programs section) need structured scheduling data.

## Decisions

| Decision | Choice |
|---|---|
| Time model | Single time slot across all meeting days |
| `schedule` column | Drop entirely, format in presenter |
| Required at creation? | No — all scheduling fields optional |
| Events | Add `program_schedule_updated` event |
| Storage approach | Flat columns on `programs` table |
| Display formatting | Presenter function |

## Domain Model

Four new fields on `Program`, replacing `schedule`:

| Field | Type | Required | Notes |
|---|---|---|---|
| `meeting_days` | `[String.t()]` | No | Subset of weekday names |
| `meeting_start_time` | `Time.t() \| nil` | No | Paired with end_time |
| `meeting_end_time` | `Time.t() \| nil` | No | Must be > start_time |
| `start_date` | `Date.t() \| nil` | No | Must be < end_date |

`end_date` already exists on the model.

### Validation Rules

- `meeting_days`: each element must be a valid weekday name
- Times are paired: if one is set, both must be set
- `meeting_end_time > meeting_start_time`
- If both dates set, `start_date < end_date`

## Persistence

### Migration

- Add `meeting_days` (`{:array, :string}`, default `[]`)
- Add `meeting_start_time` (`:time`, nullable)
- Add `meeting_end_time` (`:time`, nullable)
- Add `start_date` (`:date`, nullable)
- Remove `schedule` column

### Schema & Mapper

Schema gets four new fields with changeset validations mirroring domain rules. Mapper maps directly — no schedule string computation.

## Web Layer

### Provider Form

New "Schedule" section in `program_form/1` component:

- **Meeting days**: Multi-select checkboxes (Mon–Sun)
- **Start time / End time**: Native `type="time"` inputs, side by side
- **Start date / End date**: Native `type="date"` inputs, side by side

All optional. Sits between Location and Description fields.

### Presenter

`ProgramPresenter.format_schedule/1`:

- Days abbreviated: "Mon & Wed" or "Mon, Wed & Fri"
- Times as 12h: "4:00 - 5:30 PM"
- Combined: "Mon & Wed, 4:00 - 5:30 PM"
- Date range: "Jan 15 - Jun 30, 2026"
- Returns `nil` if no data

### Display

Program cards and detail page call presenter instead of rendering `schedule` string directly. Hidden when no data.

## Events

- **`program_created`**: Add scheduling fields to payload
- **`program_schedule_updated`** (new): Emitted from `UpdateProgram` when scheduling fields change. Payload: program_id, provider_id, all five scheduling fields. No subscribers yet.

## Testing

- **Domain**: Pairing rules, weekday validation, time/date ordering
- **Schema**: Changeset valid/invalid attrs, edge cases
- **LiveView**: Form renders fields, create/edit with schedule data
- **Presenter**: Format variations, nil handling, single day, date range
