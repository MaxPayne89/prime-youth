# Bounded Context Restructuring Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure bounded contexts: remove Community, inline Support, split Identity into Family + Provider.

**Architecture:** Four sequential phases. Each phase compiles and passes tests before the next. Phase 1-2 are deletions (low risk). Phase 3 is the big move (Identity split). Phase 4 is documentation.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, Boundary library, DomainEventBus

**Design doc:** `docs/plans/2026-02-13-bounded-context-restructuring.md`

---

## Task 1: Remove Community Context

Community is dead code: no route, in-memory repo, prototype only.

**Files to delete:**
- `lib/klass_hero/community.ex`
- `lib/klass_hero/community/` (entire directory)
- `lib/klass_hero_web/live/community_live.ex`
- `test/klass_hero/community/` (entire directory)
- `test/klass_hero_web/live/community_live_test.exs` (if exists)

**Files to modify:**
- `lib/klass_hero/application.ex` — remove Community DomainEventBus (lines ~152-164) and InMemoryPostRepository (line ~217)
- `lib/klass_hero_web.ex` — remove `KlassHero.Community` from Boundary deps (line ~29)
- `config/config.exs` — remove `:community` config block (lines ~67-69)

**Step 1: Delete all Community files**

```bash
rm -rf lib/klass_hero/community.ex lib/klass_hero/community/
rm -f lib/klass_hero_web/live/community_live.ex
rm -rf test/klass_hero/community/
rm -f test/klass_hero_web/live/community_live_test.exs
```

**Step 2: Remove Community from application.ex**

In `lib/klass_hero/application.ex`:
- Remove `KlassHero.Community` from `use Boundary, deps:` list
- Remove the Community DomainEventBus `Supervisor.child_spec` block (id: `:community_domain_event_bus`)
- Remove `KlassHero.Community.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository` from `in_memory_repositories/0`

**Step 3: Remove Community from klass_hero_web.ex**

In `lib/klass_hero_web.ex`:
- Remove `KlassHero.Community` from `use Boundary, deps:` list

**Step 4: Remove Community config**

In `config/config.exs`:
- Remove the `# Configure Community bounded context` block

**Step 5: Verify**

Run: `mix compile --warnings-as-errors`
Expected: PASS (0 warnings, 0 errors)

Run: `mix test`
Expected: All tests pass

**Step 6: Commit**

```bash
git add -A && git commit -m "refactor: remove Community bounded context (dead code)"
```

---

## Task 2: Inline Support Context

Strip the Support DDD structure. Keep ContactLive working with a simple schema.

**Files to delete:**
- `lib/klass_hero/support.ex`
- `lib/klass_hero/support/` (entire directory)
- `test/klass_hero/support/` (entire directory)

**Files to create:**
- `lib/klass_hero_web/schemas/contact_form.ex` — simple embedded schema (from existing `Support.Domain.Models.ContactForm`)

**Files to modify:**
- `lib/klass_hero_web/live/contact_live.ex` — update alias, inline submission logic
- `lib/klass_hero/application.ex` — remove Support DomainEventBus and Boundary dep
- `lib/klass_hero_web.ex` — remove `KlassHero.Support` from Boundary deps
- `config/config.exs` — remove `:support` config block

**Step 1: Create the simple ContactForm schema**

Create `lib/klass_hero_web/schemas/contact_form.ex`:

```elixir
defmodule KlassHeroWeb.Schemas.ContactForm do
  @moduledoc """
  Embedded schema for contact form validation.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @required_fields [:name, :email, :subject, :message]
  @valid_subjects ~w(general program booking instructor technical other)

  @primary_key false
  embedded_schema do
    field :name, :string
    field :email, :string
    field :subject, :string
    field :message, :string
  end

  def changeset(contact_form \\ %__MODULE__{}, attrs) do
    contact_form
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_format(:email, ~r/@/, message: "must be a valid email address")
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:message, min: 10, max: 1000)
    |> validate_inclusion(:subject, @valid_subjects)
  end
end
```

**Step 2: Update ContactLive**

In `lib/klass_hero_web/live/contact_live.ex`:

Replace:
```elixir
alias KlassHero.Support.Application.UseCases.SubmitContactForm
alias KlassHero.Support.Domain.Models.ContactForm
```

With:
```elixir
alias KlassHeroWeb.Schemas.ContactForm
```

Replace the `handle_event("submit", ...)` callback. The current implementation calls `SubmitContactForm.execute/1` which validates, builds a domain entity, and logs. Replace with direct validation + logging:

```elixir
@impl true
def handle_event("submit", %{"contact" => contact_params}, socket) do
  changeset = ContactForm.changeset(%ContactForm{}, contact_params)

  case Ecto.Changeset.apply_action(changeset, :insert) do
    {:ok, validated_form} ->
      Logger.info("Contact form submitted",
        name: validated_form.name,
        email: validated_form.email,
        subject: validated_form.subject
      )

      {:noreply,
       socket
       |> assign(submission_status: :success)
       |> assign(form: to_form(ContactForm.changeset(%ContactForm{}, %{}), as: :contact))}

    {:error, changeset} ->
      {:noreply, assign(socket, form: to_form(changeset, as: :contact))}
  end
end
```

Note: The existing repository was logging-only (no DB persistence). We preserve the Logger.info call for observability.

**Step 3: Delete Support context files**

```bash
rm -rf lib/klass_hero/support.ex lib/klass_hero/support/
rm -rf test/klass_hero/support/
```

**Step 4: Remove Support from application.ex**

In `lib/klass_hero/application.ex`:
- Remove `KlassHero.Support` from `use Boundary, deps:` list
- Remove the Support DomainEventBus `Supervisor.child_spec` block (id: `:support_domain_event_bus`)

**Step 5: Remove Support from klass_hero_web.ex**

In `lib/klass_hero_web.ex`:
- Remove `KlassHero.Support` from `use Boundary, deps:` list

**Step 6: Remove Support config**

In `config/config.exs`:
- Remove the `# Configure Support bounded context` block (lines ~149-151)

**Step 7: Verify**

Run: `mix compile --warnings-as-errors`
Expected: PASS

Run: `mix test`
Expected: All tests pass (Support tests were deleted, ContactLive test should still work if it exists)

**Step 8: Commit**

```bash
git add -A && git commit -m "refactor: inline Support context into ContactLive"
```

---

## Task 3: Create Family Context (from Identity)

Move parent profiles, children, consents, and referral codes into `KlassHero.Family`.

This is the largest task. The strategy: create the Family directory structure, move files with module renames, create the Family facade, update config, update cross-context references.

**Module rename pattern:** `KlassHero.Identity.*` -> `KlassHero.Family.*` for all family-domain files.

### Step 1: Create Family directory structure

```bash
mkdir -p lib/klass_hero/family/domain/{models,ports,services,events}
mkdir -p lib/klass_hero/family/application/use_cases/{parents,children,consents}
mkdir -p lib/klass_hero/family/adapters/driven/persistence/{schemas,mappers,repositories}
mkdir -p lib/klass_hero/family/adapters/driven/events/event_handlers
```

### Step 2: Move and rename domain models (Family)

Move these files, renaming all `KlassHero.Identity.*` modules to `KlassHero.Family.*`:

| Source | Destination |
|--------|------------|
| `identity/domain/models/parent_profile.ex` | `family/domain/models/parent_profile.ex` |
| `identity/domain/models/child.ex` | `family/domain/models/child.ex` |
| `identity/domain/models/consent.ex` | `family/domain/models/consent.ex` |

For each file, rename the module. Example for `child.ex`:
- From: `defmodule KlassHero.Identity.Domain.Models.Child`
- To: `defmodule KlassHero.Family.Domain.Models.Child`

### Step 3: Move and rename domain ports (Family)

| Source | Destination |
|--------|------------|
| `identity/domain/ports/for_storing_parent_profiles.ex` | `family/domain/ports/for_storing_parent_profiles.ex` |
| `identity/domain/ports/for_storing_children.ex` | `family/domain/ports/for_storing_children.ex` |
| `identity/domain/ports/for_storing_consents.ex` | `family/domain/ports/for_storing_consents.ex` |

Rename modules and update any `@behaviour` or alias references within each file.

### Step 4: Move and rename domain services (Family)

| Source | Destination |
|--------|------------|
| `identity/domain/services/referral_code_generator.ex` | `family/domain/services/referral_code_generator.ex` |

### Step 5: Create Family domain events

Create `lib/klass_hero/family/domain/events/family_events.ex` — copy from `identity_events.ex`, rename module to `KlassHero.Family.Domain.Events.FamilyEvents`.

Create `lib/klass_hero/family/domain/events/family_integration_events.ex` — copy from `identity_integration_events.ex`, rename module to `KlassHero.Family.Domain.Events.FamilyIntegrationEvents`. Change `@source_context` from `:identity` to `:family`.

### Step 6: Move and rename use cases (Family)

| Source | Destination |
|--------|------------|
| `identity/application/use_cases/parents/create_parent_profile.ex` | `family/application/use_cases/parents/create_parent_profile.ex` |
| `identity/application/use_cases/children/create_child.ex` | `family/application/use_cases/children/create_child.ex` |
| `identity/application/use_cases/children/update_child.ex` | `family/application/use_cases/children/update_child.ex` |
| `identity/application/use_cases/children/delete_child.ex` | `family/application/use_cases/children/delete_child.ex` |
| `identity/application/use_cases/consents/grant_consent.ex` | `family/application/use_cases/consents/grant_consent.ex` |
| `identity/application/use_cases/consents/withdraw_consent.ex` | `family/application/use_cases/consents/withdraw_consent.ex` |

Rename all modules and update internal aliases (e.g., `alias KlassHero.Identity.Domain.Ports.*` -> `alias KlassHero.Family.Domain.Ports.*`).

### Step 7: Move and rename persistence layer (Family)

**Schemas:**

| Source | Destination |
|--------|------------|
| `identity/adapters/driven/persistence/schemas/parent_profile_schema.ex` | `family/adapters/driven/persistence/schemas/parent_profile_schema.ex` |
| `identity/adapters/driven/persistence/schemas/child_schema.ex` | `family/adapters/driven/persistence/schemas/child_schema.ex` |
| `identity/adapters/driven/persistence/schemas/consent_schema.ex` | `family/adapters/driven/persistence/schemas/consent_schema.ex` |

**Mappers:**

| Source | Destination |
|--------|------------|
| `identity/adapters/driven/persistence/mappers/parent_profile_mapper.ex` | `family/adapters/driven/persistence/mappers/parent_profile_mapper.ex` |
| `identity/adapters/driven/persistence/mappers/child_mapper.ex` | `family/adapters/driven/persistence/mappers/child_mapper.ex` |
| `identity/adapters/driven/persistence/mappers/consent_mapper.ex` | `family/adapters/driven/persistence/mappers/consent_mapper.ex` |

**Repositories:**

| Source | Destination |
|--------|------------|
| `identity/adapters/driven/persistence/repositories/parent_profile_repository.ex` | `family/adapters/driven/persistence/repositories/parent_profile_repository.ex` |
| `identity/adapters/driven/persistence/repositories/child_repository.ex` | `family/adapters/driven/persistence/repositories/child_repository.ex` |
| `identity/adapters/driven/persistence/repositories/consent_repository.ex` | `family/adapters/driven/persistence/repositories/consent_repository.ex` |

**Change modules:**

| Source | Destination |
|--------|------------|
| `identity/adapters/driven/persistence/change_child.ex` | `family/adapters/driven/persistence/change_child.ex` |

**Shared helpers — `mapper_helpers.ex`:** This file is used by both Family and Provider mappers. Decide at implementation time: either duplicate into both contexts or move to `KlassHero.Shared`. Check if Provider mappers also use it.

### Step 8: Create Family event handler

Create `lib/klass_hero/family/adapters/driven/events/family_event_handler.ex`:

Extract from current `IdentityEventHandler` the `user_registered` (parent profile creation only) and `user_anonymized` (child/consent anonymization) handling. Drop the provider profile creation — that moves to Provider.

The handler subscribes to: `[:user_registered, :user_anonymized]`

On `user_registered`: check if `"parent"` is in `intended_roles`, create parent profile if so.
On `user_anonymized`: call `Family.anonymize_data_for_user/1`.

### Step 9: Create Family integration event promoter

Create `lib/klass_hero/family/adapters/driven/events/event_handlers/promote_integration_events.ex`:

Copy from `identity/adapters/driven/events/event_handlers/promote_integration_events.ex`. Rename module. Update alias from `IdentityIntegrationEvents` to `FamilyIntegrationEvents`.

### Step 10: Create Family facade

Create `lib/klass_hero/family.ex` with:

```elixir
defmodule KlassHero.Family do
  use Boundary,
    top_level?: true,
    deps: [KlassHero, KlassHero.Shared],
    exports: [
      Domain.Models.Child,
      Domain.Models.ParentProfile,
      Domain.Models.Consent,
      Adapters.Driven.Persistence.ChangeChild,
      Adapters.Driven.Persistence.Schemas.ParentProfileSchema
    ]

  # ... delegate all parent/child/consent functions from Identity facade
end
```

Extract all parent, child, consent, referral code, and GDPR (anonymize/export for family data) functions from the current Identity facade.

### Step 11: Verify Family compiles in isolation

Run: `mix compile --warnings-as-errors`

This will likely fail because Identity still exists and has conflicting modules. That's expected — we fix in Task 5 after Provider is also created.

**Do NOT commit yet** — Task 3 and Task 4 must be done together before the codebase compiles.

---

## Task 4: Create Provider Context (from Identity)

Move provider profiles, verification documents, and staff members into `KlassHero.Provider`.

### Step 1: Create Provider directory structure

```bash
mkdir -p lib/klass_hero/provider/domain/{models,ports,events}
mkdir -p lib/klass_hero/provider/application/use_cases/{providers,staff_members,verification}
mkdir -p lib/klass_hero/provider/adapters/driven/persistence/{schemas,mappers,repositories}
mkdir -p lib/klass_hero/provider/adapters/driven/events/event_handlers
```

### Step 2: Move and rename domain models (Provider)

| Source | Destination |
|--------|------------|
| `identity/domain/models/provider_profile.ex` | `provider/domain/models/provider_profile.ex` |
| `identity/domain/models/staff_member.ex` | `provider/domain/models/staff_member.ex` |
| `identity/domain/models/verification_document.ex` | `provider/domain/models/verification_document.ex` |

Rename all `KlassHero.Identity.*` modules to `KlassHero.Provider.*`.

### Step 3: Move and rename domain ports (Provider)

| Source | Destination |
|--------|------------|
| `identity/domain/ports/for_storing_provider_profiles.ex` | `provider/domain/ports/for_storing_provider_profiles.ex` |
| `identity/domain/ports/for_storing_staff_members.ex` | `provider/domain/ports/for_storing_staff_members.ex` |
| `identity/domain/ports/for_storing_verification_documents.ex` | `provider/domain/ports/for_storing_verification_documents.ex` |

### Step 4: Move and rename use cases (Provider)

| Source | Destination |
|--------|------------|
| `identity/application/use_cases/providers/create_provider_profile.ex` | `provider/application/use_cases/providers/create_provider_profile.ex` |
| `identity/application/use_cases/providers/update_provider_profile.ex` | `provider/application/use_cases/providers/update_provider_profile.ex` |
| `identity/application/use_cases/providers/verify_provider.ex` | `provider/application/use_cases/providers/verify_provider.ex` |
| `identity/application/use_cases/providers/unverify_provider.ex` | `provider/application/use_cases/providers/unverify_provider.ex` |
| `identity/application/use_cases/staff_members/create_staff_member.ex` | `provider/application/use_cases/staff_members/create_staff_member.ex` |
| `identity/application/use_cases/staff_members/update_staff_member.ex` | `provider/application/use_cases/staff_members/update_staff_member.ex` |
| `identity/application/use_cases/staff_members/delete_staff_member.ex` | `provider/application/use_cases/staff_members/delete_staff_member.ex` |
| `identity/application/use_cases/verification/submit_verification_document.ex` | `provider/application/use_cases/verification/submit_verification_document.ex` |
| `identity/application/use_cases/verification/approve_verification_document.ex` | `provider/application/use_cases/verification/approve_verification_document.ex` |
| `identity/application/use_cases/verification/reject_verification_document.ex` | `provider/application/use_cases/verification/reject_verification_document.ex` |
| `identity/application/use_cases/verification/get_verification_document_preview.ex` | `provider/application/use_cases/verification/get_verification_document_preview.ex` |

### Step 5: Move and rename persistence layer (Provider)

**Schemas:**

| Source | Destination |
|--------|------------|
| `identity/adapters/driven/persistence/schemas/provider_profile_schema.ex` | `provider/adapters/driven/persistence/schemas/provider_profile_schema.ex` |
| `identity/adapters/driven/persistence/schemas/staff_member_schema.ex` | `provider/adapters/driven/persistence/schemas/staff_member_schema.ex` |
| `identity/adapters/driven/persistence/schemas/verification_document_schema.ex` | `provider/adapters/driven/persistence/schemas/verification_document_schema.ex` |

**Mappers:**

| Source | Destination |
|--------|------------|
| `identity/adapters/driven/persistence/mappers/provider_profile_mapper.ex` | `provider/adapters/driven/persistence/mappers/provider_profile_mapper.ex` |
| `identity/adapters/driven/persistence/mappers/staff_member_mapper.ex` | `provider/adapters/driven/persistence/mappers/staff_member_mapper.ex` |
| `identity/adapters/driven/persistence/mappers/verification_document_mapper.ex` | `provider/adapters/driven/persistence/mappers/verification_document_mapper.ex` |

**Repositories:**

| Source | Destination |
|--------|------------|
| `identity/adapters/driven/persistence/repositories/provider_profile_repository.ex` | `provider/adapters/driven/persistence/repositories/provider_profile_repository.ex` |
| `identity/adapters/driven/persistence/repositories/staff_member_repository.ex` | `provider/adapters/driven/persistence/repositories/staff_member_repository.ex` |
| `identity/adapters/driven/persistence/repositories/verification_document_repository.ex` | `provider/adapters/driven/persistence/repositories/verification_document_repository.ex` |

**Change modules:**

| Source | Destination |
|--------|------------|
| `identity/adapters/driven/persistence/change_provider_profile.ex` | `provider/adapters/driven/persistence/change_provider_profile.ex` |
| `identity/adapters/driven/persistence/change_staff_member.ex` | `provider/adapters/driven/persistence/change_staff_member.ex` |

### Step 6: Create Provider event handler

Create `lib/klass_hero/provider/adapters/driven/events/provider_event_handler.ex`:

Extract from current `IdentityEventHandler` the `user_registered` (provider profile creation only) and `user_anonymized` (provider data anonymization) handling.

On `user_registered`: check if `"provider"` is in `intended_roles`, create provider profile if so.
On `user_anonymized`: call `Provider.anonymize_data_for_user/1` (if provider profile exists for user).

### Step 7: Create Provider facade

Create `lib/klass_hero/provider.ex` with:

```elixir
defmodule KlassHero.Provider do
  use Boundary,
    top_level?: true,
    deps: [KlassHero, KlassHero.Shared],
    exports: [
      Domain.Models.ProviderProfile,
      Domain.Models.StaffMember,
      Domain.Models.VerificationDocument,
      Adapters.Driven.Persistence.ChangeProviderProfile,
      Adapters.Driven.Persistence.ChangeStaffMember
    ]

  # ... delegate all provider/staff/verification functions from Identity facade
end
```

---

## Task 5: Delete Identity Context and Wire Everything Up

Now that Family and Provider exist, delete Identity and update all references.

### Step 1: Delete Identity files

```bash
rm -rf lib/klass_hero/identity.ex lib/klass_hero/identity/
```

### Step 2: Update application.ex

Replace the Identity DomainEventBus with Family and Provider buses:

```elixir
# Replace identity_domain_event_bus with:
Supervisor.child_spec(
  {KlassHero.Shared.DomainEventBus,
   context: KlassHero.Family,
   handlers: [
     {:child_data_anonymized,
      {KlassHero.Family.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
       :handle}, priority: 10}
   ]},
  id: :family_domain_event_bus
),
Supervisor.child_spec(
  {KlassHero.Shared.DomainEventBus,
   context: KlassHero.Provider,
   handlers: []},
  id: :provider_domain_event_bus
),
```

Replace the Identity integration event subscriber with two:

```elixir
# Replace identity_integration_event_subscriber with:
Supervisor.child_spec(
  {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
   handler: KlassHero.Family.Adapters.Driven.Events.FamilyEventHandler,
   topics: [
     "integration:accounts:user_registered",
     "integration:accounts:user_anonymized"
   ],
   message_tag: :integration_event,
   event_label: "Integration event"},
  id: :family_integration_event_subscriber
),
Supervisor.child_spec(
  {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
   handler: KlassHero.Provider.Adapters.Driven.Events.ProviderEventHandler,
   topics: [
     "integration:accounts:user_registered",
     "integration:accounts:user_anonymized"
   ],
   message_tag: :integration_event,
   event_label: "Integration event"},
  id: :provider_integration_event_subscriber
),
```

Update Participation subscriber topic:

```elixir
# Was: "integration:identity:child_data_anonymized"
topics: ["integration:family:child_data_anonymized"]
```

Update `use Boundary, deps:` — replace `KlassHero.Identity` with `KlassHero.Family, KlassHero.Provider`.

### Step 3: Update config/config.exs

Replace the `:identity` config block with two:

```elixir
# Configure Family bounded context
config :klass_hero, :family,
  repo: KlassHero.Repo,
  for_storing_parent_profiles:
    KlassHero.Family.Adapters.Driven.Persistence.Repositories.ParentProfileRepository,
  for_storing_children:
    KlassHero.Family.Adapters.Driven.Persistence.Repositories.ChildRepository,
  for_storing_consents:
    KlassHero.Family.Adapters.Driven.Persistence.Repositories.ConsentRepository

# Configure Provider bounded context
config :klass_hero, :provider,
  repo: KlassHero.Repo,
  for_storing_provider_profiles:
    KlassHero.Provider.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository,
  for_storing_verification_documents:
    KlassHero.Provider.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository,
  for_storing_staff_members:
    KlassHero.Provider.Adapters.Driven.Persistence.Repositories.StaffMemberRepository
```

### Step 4: Update klass_hero_web.ex

Replace `KlassHero.Identity` with `KlassHero.Family, KlassHero.Provider` in Boundary deps.

### Step 5: Update web layer references

**`lib/klass_hero_web/helpers/identity_helpers.ex`:**
- Rename file to `lib/klass_hero_web/helpers/family_helpers.ex`
- Rename module to `KlassHeroWeb.Helpers.FamilyHelpers`
- Replace `alias KlassHero.Identity` with `alias KlassHero.Family`
- Update all `Identity.` calls to `Family.`
- Update all LiveViews that import this helper

**LiveViews referencing Identity — update aliases:**
- `lib/klass_hero_web/live/settings/children_live.ex` — `Identity` -> `Family`
- `lib/klass_hero_web/live/dashboard_live.ex` — `Identity` -> `Family` (for children/parent)
- `lib/klass_hero_web/live/program_detail_live.ex` — `Identity` -> `Family` (for children)
- `lib/klass_hero_web/live/parent/participation_history_live.ex` — `Identity` -> `Family`
- `lib/klass_hero_web/controllers/user_data_export_controller.ex` — `Identity` -> `Family` and/or `Provider`
- `lib/klass_hero_web/live/provider/dashboard_live.ex` — `Identity` -> `Provider`
- `lib/klass_hero_web/live/admin/verifications_live.ex` — `Identity` -> `Provider`

**Presenters — update aliases:**
- `lib/klass_hero_web/presenters/child_presenter.ex` — `Identity.Domain.Models.Child` -> `Family.Domain.Models.Child`
- `lib/klass_hero_web/presenters/provider_presenter.ex` — `Identity.Domain.Models.ProviderProfile` -> `Provider.Domain.Models.ProviderProfile`
- `lib/klass_hero_web/presenters/staff_member_presenter.ex` — `Identity.Domain.Models.StaffMember` -> `Provider.Domain.Models.StaffMember`

**Components — update aliases:**
- `lib/klass_hero_web/components/provider_components.ex` — `Identity.Domain.Models.VerificationDocument` -> `Provider.Domain.Models.VerificationDocument`

### Step 6: Update cross-context references

**Participation child info resolver:**
- `lib/klass_hero/participation/adapters/driven/identity_context/child_info_resolver.ex`
  - Rename directory: `identity_context/` -> `family_context/`
  - Rename module: `IdentityContext.ChildInfoResolver` -> `FamilyContext.ChildInfoResolver`
  - Replace `alias KlassHero.Identity` with `alias KlassHero.Family`
  - Update all `Identity.` calls to `Family.`
  - Update docstring references

- `config/config.exs` participation config:
  - `child_info_resolver: KlassHero.Participation.Adapters.Driven.FamilyContext.ChildInfoResolver`

- `lib/klass_hero/participation.ex` Boundary deps: add `KlassHero.Family`

**Enrollment:**
- `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository.ex`
  - Replace `alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ParentProfileSchema`
  - With `alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ParentProfileSchema`

- `lib/klass_hero/enrollment.ex` Boundary deps: replace `KlassHero.Identity` with `KlassHero.Family`

**ProgramCatalog verified providers projection:**
- `lib/klass_hero/program_catalog/adapters/driven/projections/verified_providers.ex`
  - Check if it references Identity. If so, update to Provider.

### Step 7: Update test fixtures

- `test/support/fixtures/identity_fixtures.ex`
  - Rename to `test/support/fixtures/provider_fixtures.ex` (it only has provider + staff fixtures)
  - Rename module: `KlassHero.IdentityFixtures` -> `KlassHero.ProviderFixtures`
  - Update all aliases from `Identity.*` to `Provider.*`
  - Update all test files that `import KlassHero.IdentityFixtures` to `import KlassHero.ProviderFixtures`

### Step 8: Move and rename all Identity tests

Move tests following the same Family/Provider split as source files. Rename all module references inside test files.

**Family tests:**
- `test/klass_hero/identity/domain/models/parent_profile_test.exs` -> `test/klass_hero/family/domain/models/parent_profile_test.exs`
- `test/klass_hero/identity/domain/models/child_test.exs` -> `test/klass_hero/family/domain/models/child_test.exs`
- `test/klass_hero/identity/domain/models/consent_test.exs` -> `test/klass_hero/family/domain/models/consent_test.exs`
- `test/klass_hero/identity/domain/events/identity_events_test.exs` -> `test/klass_hero/family/domain/events/family_events_test.exs`
- All children use case tests -> `test/klass_hero/family/application/use_cases/children/`
- All consent use case tests -> `test/klass_hero/family/application/use_cases/consents/`
- Parent profile repo test -> `test/klass_hero/family/adapters/driven/persistence/repositories/`
- Child repo/schema/mapper tests -> `test/klass_hero/family/adapters/driven/persistence/`
- Consent repo test -> `test/klass_hero/family/adapters/driven/persistence/repositories/`
- GDPR tests (anonymize/export) -> `test/klass_hero/family/` (the family-relevant portions)

**Provider tests:**
- `test/klass_hero/identity/domain/models/provider_profile_test.exs` -> `test/klass_hero/provider/`
- `test/klass_hero/identity/domain/models/staff_member_test.exs` -> `test/klass_hero/provider/`
- `test/klass_hero/identity/domain/models/verification_document_test.exs` -> `test/klass_hero/provider/`
- All provider use case tests -> `test/klass_hero/provider/application/use_cases/providers/`
- All staff member tests -> `test/klass_hero/provider/application/use_cases/staff_members/`
- All verification tests -> `test/klass_hero/provider/application/use_cases/verification/`
- Provider repo/mapper tests -> `test/klass_hero/provider/adapters/driven/persistence/`
- Staff member integration test -> `test/klass_hero/provider/`

**Event handler tests:** Split into family and provider test files.

**Facade test (`identity_test.exs`):** Split into `family_test.exs` and `provider_test.exs`.

**Participation cross-context test:**
- `test/klass_hero/participation/adapters/driven/identity_context/child_info_resolver_test.exs`
  - Rename directory and module references to `family_context/`

### Step 9: Delete remaining Identity files

```bash
rm -rf test/klass_hero/identity/ test/klass_hero/identity_test.exs
```

### Step 10: Verify

Run: `mix compile --warnings-as-errors`
Expected: PASS (0 warnings, 0 errors)

Run: `mix test`
Expected: All tests pass

### Step 11: Commit

```bash
git add -A && git commit -m "refactor: split Identity into Family + Provider contexts"
```

---

## Task 6: Update Documentation

### Step 1: Update CLAUDE.md

In the root `CLAUDE.md`, update the **Active contexts** list:
- Remove Identity, Community, Support
- Add Family, Provider
- Update descriptions

Update any other references to Identity throughout the file.

### Step 2: Update .claude/rules/domain-architecture.md

Update the bounded context list and descriptions.

### Step 3: Update .claude/rules/authentication.md

If it references Identity, update to Family/Provider as appropriate.

### Step 4: Update docs/technical-architecture.md

Update the context map and any Identity references.

### Step 5: Verify

Run: `mix compile --warnings-as-errors && mix test`

### Step 6: Commit

```bash
git add -A && git commit -m "docs: update documentation for bounded context restructuring"
```

---

## Execution Notes

- **Tasks 1-2** are independent deletions. Safe and fast.
- **Tasks 3-5** must be done as a unit — the codebase won't compile with both Identity and Family/Provider existing simultaneously (duplicate module names after rename). The recommended approach is to do all three in one pass and compile once at the end.
- **Task 6** is documentation cleanup.
- Each commit message should NOT reference Claude.
- Run `mix precommit` before the final push to catch any remaining warnings.
