# Domain Documentation

This directory contains the domain analysis and architecture documentation for Klass Hero, split into business and technical perspectives.

## File Structure

### 📖 [domain-stories.md](./domain-stories.md)
**For: Business stakeholders, product owners, domain experts**

Contains the business-focused domain stories using Domain Storytelling methodology:
- Core domain stories (Program Discovery, Enrollment, Progress Tracking)
- Visual Mermaid diagrams showing user flows
- Business concepts and work objects
- Non-technical narrative descriptions

Perfect for collaboration with non-technical team members who need to understand and contribute to the business domain without getting overwhelmed by implementation details.

### ⚙️ [technical-architecture.md](./technical-architecture.md)
**For: Developers, architects, technical team**

Contains the technical implementation details:
- Bounded contexts and responsibilities
- Ports & Adapters architecture patterns
- Elixir/Phoenix code examples
- Use case mappings
- Repository patterns and database adapters

Focuses on how the business domain translates into clean architecture and maintainable code.

## Collaboration Workflow

1. **Business changes**: Edit `domain-stories.md` to update business flows and domain understanding
2. **Technical changes**: Edit `technical-architecture.md` to update implementation patterns and code structure
3. **Cross-reference**: Both files link to each other to maintain alignment between business and technical perspectives

This separation enables:
- ✅ Non-technical stakeholders can contribute to domain stories
- ✅ Technical team can iterate on implementation separately
- ✅ Clear boundaries between business logic and technical concerns
- ✅ Better version control of changes (business vs technical)

## Living Documentation

Auto-generated documentation that stays in sync with the codebase. Use `/doc` to generate or update.

### [Context Map](./context-map.md)
High-level Mermaid diagram showing all bounded contexts and their relationships.

### [Context Docs](./contexts/)
Per-context canvases documenting purpose, owned data, features, communication, and glossary.

| Context | Doc |
|---|---|
| [Accounts](./contexts/accounts/README.md) | Auth, registration, tokens |
| [Family](./contexts/family/README.md) | Parents, children, consents |
| [Provider](./contexts/provider/README.md) | Provider profiles, staff, verification |
| [Program Catalog](./contexts/program-catalog/README.md) | Programs, categories, pricing |
| [Enrollment](./contexts/enrollment/README.md) | Bookings, fees, subscriptions |
| [Messaging](./contexts/messaging/README.md) | Conversations, messages |
| [Participation](./contexts/participation/README.md) | Sessions, attendance, check-in |
| [Shared](./contexts/shared/README.md) | Event bus, helpers |

### [Cross-Context Flows](./flows/)
End-to-end flows that span multiple bounded contexts.

### Templates
- [`feature.md`](./templates/feature.md) — Feature capability doc
- [`context-canvas.md`](./templates/context-canvas.md) — Bounded context canvas
- [`cross-context-flow.md`](./templates/cross-context-flow.md) — Cross-context flow doc

## Getting Started

- **New to the project?** Start with `domain-stories.md` to understand the business domain
- **Want the big picture?** See the [Context Map](./context-map.md) for how contexts relate
- **Looking for a specific feature?** Browse the [context docs](./contexts/)
- **Ready to implement?** Check the relevant context doc, then read the code
- **Contributing business insights?** Focus on `domain-stories.md` and let the technical team handle implementation details