# Enrollment Classifier Domain Service (#154)

## Context

PR review identified business logic (expiration detection, active/expired splitting, sorting) living in DashboardLive. This logic belongs in a domain service per DDD — pure function, receives data, returns deterministic result.

## New Module

`lib/klass_hero/enrollment/domain/services/enrollment_classifier.ex`

Pure domain service. Receives `{Enrollment.t(), Program.t()}` tuples + today's date. Returns `{active, expired}` both sorted.

### Public API

```elixir
@spec classify([{Enrollment.t(), Program.t()}], Date.t()) ::
        {[{Enrollment.t(), Program.t()}], [{Enrollment.t(), Program.t()}]}
def classify(enrollment_programs, today)
```

### Logic

- Expired if enrollment status is `:completed` or `:cancelled`
- Expired if program `end_date` is before `today`
- Otherwise active
- Active sorted by `program.start_date` ascending (nil pushed to end)
- Expired sorted by `program.end_date` descending (nil pushed to end)

## Facade

Add to `lib/klass_hero/enrollment.ex`:

```elixir
def classify_family_programs(enrollment_programs, today) do
  EnrollmentClassifier.classify(enrollment_programs, today)
end
```

## DashboardLive Changes

Replace inline classification with facade call. Keep data fetching + error handling in LiveView.

## Testing

Pure function — build structs inline, no DB needed.
