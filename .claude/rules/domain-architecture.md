# Domain Architecture

The project follows Domain-Driven Design with Ports & Adapters architecture (Hexagonal Architecture).

## Bounded Contexts

1. **Program Catalog Context** - Program discovery, details, availability
2. **Enrollment Context** - Enrollment process from selection to payment
3. **Family Context** - Parent profiles, children management, consents, referral codes, GDPR family data
4. **Provider Context** - Provider profiles, staff members, verification documents
5. **Progress Tracking Context** - Child progress and achievements
6. **Review & Rating Context** - Program reviews and feedback

## Architecture Documentation

**Start here for architectural guidance:**

- `docs/DDD_ARCHITECTURE.md` - Comprehensive DDD patterns, code templates, and directory structures
- `docs/technical-architecture.md` - Klass Hero bounded context definitions and examples
- `docs/domain-stories.md` - Business domain understanding

## Authentication Note

The authentication system uses Phoenix's standard `phx.gen.auth` for simplicity and maintainability. For future bounded contexts (Program Catalog, Enrollment, Family, Provider, etc.), the DDD/Ports & Adapters architecture documented in the above files will be followed.

## Key Patterns for Future Contexts

- Domain entities and value objects (pure Elixir structs)
- Repository ports and Ecto adapters
- Use case orchestration patterns
- Phoenix web adapters (driving adapters)
- Configuration and dependency injection
