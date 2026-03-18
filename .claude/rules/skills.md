# Available Skills

The following specialized skills are available for this repository and should be consulted when relevant:

## idiomatic-elixir

Elixir idioms for writing clean, functional, and domain-driven code covering patterns from pattern matching to Phoenix contexts.

**Use when:**

- Writing new Elixir code
- Designing Phoenix applications with DDD principles
- Refactoring code
- Implementing bounded contexts
- Leveraging OTP patterns effectively

## elixir-ecto-patterns

Phoenix Ecto patterns for clean, maintainable data access covering production-ready patterns.

**Use when:**

- Building Phoenix applications with database-backed features
- Designing clean context boundaries
- Optimizing database queries
- Implementing transactions
- Refactoring existing Ecto code

## phoenix-pubsub

Battle-tested Phoenix PubSub patterns for building real-time backends, from single-node fan-out to multi-region handoffs.

**Use when:**

- Building real-time features (live updates, notifications, collaboration)
- Scaling WebSocket connections
- Implementing pub/sub messaging patterns

## inversion

A mental model for solving complex problems by thinking in reverse - identify failure modes first, then design solutions to avoid them.

**Use when:**

- Making critical architectural decisions
- Conducting premortems
- Reviewing code for potential failure modes
- Planning security features

## second-order

A mental model for making better decisions by thinking beyond immediate effects - consider the consequences of consequences before acting.

**Use when:**

- Evaluating major technical decisions
- Assessing long-term impact of architectural choices
- Considering tradeoffs between short-term speed and long-term maintainability

## Project-Bespoke Skills (in `.claude/skills/`)

### triage-qa-discussion

Reads a Daily QA GitHub Discussion by number, triages Carried-Forward and New Code Review findings, and systematically addresses confirmed issues.

**Use when:** `/triage-qa-discussion <discussion-number>`

### idiomatic-elixir (project version)

Enhanced version of the global skill with auto-triggering on `.ex`/`.exs` files and modern Elixir 1.17–1.20 patterns (type system, Duration, built-in JSON, parameterized tests).

**Triggers automatically** when working on any Elixir file.
