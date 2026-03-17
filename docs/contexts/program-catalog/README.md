# Context: Program Catalog

> The Program Catalog is the central registry for all afterschool programs, camps, and workshops offered on Klass Hero. It handles program discovery, listing, filtering, and detail viewing for parents — and program creation and management for providers. Think of it as the "storefront window" that parents browse to find activities for their children.

## What This Context Owns

- **Domain Concepts:** Program (aggregate root), Instructor (value object — ACL over Provider's StaffMember), RegistrationPeriod (value object), ProgramListing (CQRS read DTO), ProgramCategories, ProgramPricing, TrendingSearches
- **Data:**
  - `programs` table (write model — title, description, category, price, pricing_period, age_range, schedule, location, cover_image_url, instructor fields, registration dates, lock_version)
  - `program_listings` table (read model — denormalized flat projection with provider_verified flag)
- **Processes:** Program CRUD with optimistic locking, CQRS projections (ProgramListings GenServer, VerifiedProviders GenServer), cursor-based paginated browsing, category filtering, in-memory search, featured program selection, remaining capacity lookup (via Enrollment ACL)

## Key Features

| Feature | Status | Doc |
|---|---|---|
| Browse Programs (Search, Filter, Featured, Trending) | Active | [browse-programs](features/browse-programs.md) |
| Program Detail View | Active | [program-detail-view](features/program-detail-view.md) |
| Create & Update Program | Active | [create-and-update-program](features/create-and-update-program.md) |
| CQRS Read Model & Projections | Active | [cqrs-read-model](features/cqrs-read-model.md) |
| Registration Period | Active | [registration-period](features/registration-period.md) |
| Remaining Capacity (via Enrollment ACL) | Active | [remaining-capacity](features/remaining-capacity.md) |

## Inbound Communication

| From Context | Event / Call | What It Triggers |
|---|---|---|
| Provider | `integration:provider:provider_verified` | Adds provider ID to in-memory VerifiedProviders set; bulk-updates `program_listings.provider_verified = true` |
| Provider | `integration:provider:provider_unverified` | Removes provider ID from VerifiedProviders set; bulk-updates `program_listings.provider_verified = false` |
| Enrollment | `participant_policy_set` (domain event) | Currently a no-op (acknowledged); reserved for future search indexing by eligibility criteria |
| Messaging | `list_ended_program_ids/1` (cross-context query) | Returns program IDs whose `end_date` has passed, used for message retention policy |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| Any subscriber | `integration:program_catalog:program_created` | Notifies that a new program was created (payload: program_id, provider_id, title, category, instructor, schedule) |
| Any subscriber | `integration:program_catalog:program_updated` | Notifies that a program was updated (payload: program_id + changed fields) |
| Enrollment (via ACL) | `Enrollment.remaining_capacity/1`, `Enrollment.get_remaining_capacities/1` | Queries remaining enrollment capacity for display alongside program listings |

## Ubiquitous Language

| Term | Meaning |
|---|---|
| **Program** | An afterschool activity, camp, or workshop that parents can discover and enroll children in |
| **Instructor** | The person leading a program — a read-only projection of Provider's StaffMember, kept separate via an Anti-Corruption Layer |
| **Category** | A classification for programs: sports, arts, music, education, life-skills, camps, workshops |
| **Registration Period** | The enrollment open/close window for a program. Status is one of: always_open (no dates set), upcoming (before start), open (within window), closed (after end) |
| **Program Listing** | A denormalized, read-optimized view of a program used for search results and catalog pages (CQRS read model) |
| **Verified Provider** | A provider whose identity has been confirmed — tracked via an in-memory projection (MapSet) bootstrapped from the Provider context |
| **Free Program** | A program with a price of 0 |
| **Featured Programs** | The first 2 programs shown on the homepage |
| **Trending Searches** | A curated list of popular search terms (Swimming, Math Tutor, Summer Camp, Piano, Soccer) |
| **Pricing Period** | The billing cadence for a program (e.g., per month, per session) |
| **Lock Version** | An optimistic concurrency control field — prevents lost updates when two people edit a program simultaneously |
| **Cursor** | An opaque pagination token (Base64-encoded timestamp + ID) used for seek-based pagination |
| **Remaining Capacity** | Number of open enrollment slots for a program, queried from Enrollment via an ACL |

## Business Decisions

- **CQRS with separate read/write models.** The `programs` table is the write model (source of truth). The `program_listings` table is a denormalized read projection maintained by the ProgramListings GenServer. This separates query concerns (filtering, sorting, provider_verified) from write concerns (validation, optimistic locking).
- **Projections subscribe-before-bootstrap.** ProgramListings subscribes to PubSub topics before bootstrapping from the write model. This prevents missing events that arrive between bootstrap and subscription. Bootstrap retries up to 3 times with exponential backoff before crashing to the supervisor.
- **VerifiedProviders starts before ProgramListings.** The supervision tree ensures the in-memory verified provider set is available when ProgramListings bootstraps, so each listing gets an accurate `provider_verified` flag.
- **Categories are a closed set.** Valid categories: sports, arts, music, education, life-skills, camps, workshops. "all" is a filter-only pseudo-category, not assignable to a program.
- **Pricing uses EUR exclusively.** No multi-currency support. Total price is the program price set by the provider.
- **Optimistic locking on updates.** If two users edit the same program concurrently, the second save receives `:stale_data` error instead of silently overwriting.
- **Instructor is a value object, not a reference.** Program Catalog does not depend on or reach into the Provider context at runtime — the Instructor VO is populated from persistence data only.
- **Search is in-memory, word-boundary matching.** Queries match the start of words in program titles. No full-text database search. Max query length: 100 characters.
- **Pagination is cursor-based (seek method).** Ordered by `(inserted_at DESC, id DESC)` with limit clamped to 1-100. No offset pagination.
- **`provider_id` and instructor fields are never user-castable.** Set programmatically via `put_change` to prevent form injection.
- **Registration period determines enrollment availability.** Four states: always_open (no dates), upcoming (before start), open (within window), closed (after end). Both dates optional — partial ranges are supported.
- **Trending searches are hardcoded.** Not data-driven or analytics-based.
- **Featured programs = first 2 programs.** No scoring or curation logic — just takes the first two from the full list.
- **Remaining capacity is queried, not owned.** Program Catalog delegates capacity checks to Enrollment via an Anti-Corruption Layer, keeping enrollment logic out of this context.

## Assumptions & Open Questions

- [NEEDS INPUT] Should featured programs have a curation mechanism (editorial picks, highest-rated, most-enrolled) rather than taking the first two?
- [NEEDS INPUT] Should trending searches be driven by actual search analytics instead of a hardcoded list?
- [NEEDS INPUT] Should the `end_date` field be required for all programs, or only for time-bound ones like camps?
- [NEEDS INPUT] Is there a need for program archiving/soft-delete, or is the current hard-delete sufficient?
- [NEEDS INPUT] Should the verified-provider projection affect program visibility (i.e., hide programs from unverified providers)?

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
