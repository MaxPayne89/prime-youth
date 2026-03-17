# Test Drive Report - 2026-03-17

## Scope
- Mode: branch (`refactor/445-duplicate-code` vs `main`)
- Files changed: 5 (code), 6 total with this report
- Routes affected: none (pure backend refactoring)
- UI affected: none

## Backend Checks (Tidewave MCP)

### Passed
- **PubSubBroadcaster exports**: `broadcast/3` and `pubsub_server/1` confirmed
- **DomainEvent publish/1 e2e**: created event, subscribed to derived topic, published, received `{:domain_event, event}` — event_type, aggregate_id, payload all match
- **IntegrationEvent publish/2 e2e**: created event, subscribed to explicit topic, published, received `{:integration_event, event}` — event_type, entity_id, message_tag all match
- **publish_all/1**: batch of 2 domain events returns `:ok`
- **pubsub_server/1 config resolution**: `:event_publisher` → `KlassHero.PubSub`, `:integration_event_publisher` → `KlassHero.PubSub`, missing key → `KlassHero.PubSub` (fallback works)
- **Error logs**: no errors in application logs after test-drive
- **Full test suite**: 3312 tests, 0 failures (via `mix precommit`)

### Issues Found
- None

## UI Checks
- Skipped — no UI changes on this branch

## Auto-Fixes Applied
- None

## Recommendations
- None — refactoring is clean, all behaviour contracts preserved, no regressions detected
