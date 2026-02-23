# CSV Import Controller Endpoint

**Date**: 2026-02-22
**Issue**: #176 (Bulk Enrollment and Import)
**Status**: Approved

## Context

Backend CSV import pipeline exists (`ImportEnrollmentCsv` use case, `CsvParser`, `ImportRowValidator`). Need a route to test E2E.

## Decision

Plain Phoenix controller endpoint (not LiveView). JSON request/response for easy curl/Postman/controller-test usage.

## Route

`POST /provider/enrollment/import` — multipart file upload under provider-authenticated scope.

## Flow

1. Plug receives multipart upload, streams body to temp file on disk (memory-safe by default)
2. Controller reads temp file via `File.read!/1`, passes binary to `ImportEnrollmentCsv.execute/2`
3. Returns JSON response with appropriate status code

## Authentication

- Existing `:require_authenticated_user` plug pipeline
- Provider role resolved in controller from `@current_scope`
- 403 if no provider profile

## Response Contract

| Scenario | Status | Body |
|---|---|---|
| Success | 201 | `{"created": N}` |
| Missing file | 400 | `{"error": "No file uploaded"}` |
| Not a provider | 403 | `{"error": "Provider profile required"}` |
| Parse errors | 422 | `{"errors": {"parse_errors": [...]}}` |
| Validation errors | 422 | `{"errors": {"validation_errors": [...]}}` |
| Duplicate errors | 422 | `{"errors": {"duplicate_errors": [...]}}` |

## File Size

2MB max via `Plug.Parsers` `:length` option. Sufficient for thousands of CSV rows.

## Files

- **New**: `lib/klass_hero_web/controllers/provider/enrollment_import_controller.ex`
- **New**: `test/klass_hero_web/controllers/provider/enrollment_import_controller_test.exs`
- **Modified**: `lib/klass_hero_web/router.ex` (add controller route in provider scope)
