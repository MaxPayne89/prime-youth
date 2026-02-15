# Context: Program Catalog

> The Program Catalog is the central registry for all afterschool programs, camps, and workshops offered on Klass Hero. It handles program discovery, listing, filtering, and detail viewing for parents — and program creation and management for providers. Think of it as the "storefront window" that parents browse to find activities for their children.

## What This Context Owns

- **Domain Concepts:** Program (aggregate root), Instructor (value object — anti-corruption layer over Provider's StaffMember), ProgramCategories, ProgramPricing, TrendingSearches
- **Data:** `programs` table (title, description, category, price, pricing_period, spots_available, age_range, schedule, location, cover_image_url, instructor fields, lock_version)
- **Processes:** Program CRUD with optimistic locking, cursor-based paginated browsing, category filtering, in-memory search, featured program selection, verified-provider projection (via integration events)

## Key Features

| Feature | Status | Doc |
|---|---|---|
| Browse Programs (paginated, filtered by category) | Active | — |
| Program Detail View | Active | — |
| Program Search (in-memory word-boundary matching) | Active | — |
| Featured Programs (homepage) | Active | — |
| Create Program (provider) | Active | — |
| Update Program (provider, optimistic locking) | Active | — |
| Trending Searches | Active | — |
| Verified Provider Projection | Active | — |
| Ended Program ID Listing (for Messaging retention) | Active | — |

## Inbound Communication

| From Context | Event / Call | What It Triggers |
|---|---|---|
| Provider | `integration:provider:provider_verified` | Adds provider ID to in-memory verified-providers projection |
| Provider | `integration:provider:provider_unverified` | Removes provider ID from verified-providers projection |
| Messaging | `list_ended_program_ids/1` (cross-context query) | Returns program IDs whose `end_date` has passed, used for message retention policy |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| Any subscriber | `integration:program_catalog:program_created` | Notifies that a new program was created (payload: `program_id`) |

## Ubiquitous Language

| Term | Meaning |
|---|---|
| **Program** | An afterschool activity, camp, or workshop that parents can discover and enroll children in |
| **Instructor** | The person leading a program — a read-only projection of Provider's StaffMember, kept separate via an Anti-Corruption Layer |
| **Category** | A classification for programs: sports, arts, music, education, life-skills, camps, workshops |
| **Spots Available** | How many open enrollment slots remain for a program |
| **Sold Out** | A program with zero spots available |
| **Free Program** | A program with a price of €0 |
| **Featured Programs** | The first 2 programs shown on the homepage |
| **Trending Searches** | A curated list of popular search terms (Swimming, Math Tutor, Summer Camp, Piano, Soccer) |
| **Pricing Period** | The billing cadence for a program (e.g., per month, per session) |
| **Lock Version** | An optimistic concurrency control field — prevents lost updates when two people edit a program simultaneously |
| **Cursor** | An opaque pagination token (Base64-encoded timestamp + ID) used for seek-based pagination |

## Business Decisions

- **Categories are a closed set.** Valid categories: sports, arts, music, education, life-skills, camps, workshops. "all" is a filter-only pseudo-category, not assignable to a program.
- **Pricing uses EUR (€) exclusively.** No multi-currency support. Total price calculated as `price × 4 weeks`.
- **Optimistic locking on updates.** If two users edit the same program concurrently, the second save receives `:stale_data` error instead of silently overwriting.
- **Instructor is a value object, not a reference.** Program Catalog does not depend on or reach into the Provider context at runtime — the Instructor VO is populated from persistence data only.
- **Search is in-memory, word-boundary matching.** Queries match the start of words in program titles. No full-text database search.
- **Pagination is cursor-based (seek method).** Ordered by `(inserted_at DESC, id DESC)` with limit clamped to 1–100. No offset pagination.
- **`provider_id` and instructor fields are never user-castable.** Set programmatically via `put_change` to prevent form injection.
- **Trending searches are hardcoded.** Not data-driven or analytics-based.
- **Featured programs = first 2 programs.** No scoring or curation logic — just takes the first two from the full list.

## Assumptions & Open Questions

- [NEEDS INPUT] Should featured programs have a curation mechanism (editorial picks, highest-rated, most-enrolled) rather than taking the first two?
- [NEEDS INPUT] Should trending searches be driven by actual search analytics instead of a hardcoded list?
- [NEEDS INPUT] Is the 4-week default for `calculate_total` always correct, or should program duration be a field on the program itself?
- [NEEDS INPUT] Should the `end_date` field be required for all programs, or only for time-bound ones like camps?
- [NEEDS INPUT] Is there a need for program archiving/soft-delete, or is the current hard-delete sufficient?
- [NEEDS INPUT] Should the verified-provider projection affect program visibility (i.e., hide programs from unverified providers)?

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
