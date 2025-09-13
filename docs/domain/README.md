# Domain Documentation

This directory contains the domain analysis and architecture documentation for Prime Youth, split into business and technical perspectives.

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

## Getting Started

- **New to the project?** Start with `domain-stories.md` to understand the business domain
- **Ready to implement?** Move to `technical-architecture.md` for code patterns and architecture
- **Contributing business insights?** Focus on `domain-stories.md` and let the technical team handle implementation details