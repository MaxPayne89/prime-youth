# Prime Youth Technical Architecture
*DDD & Ports & Adapters Implementation Guide*

## Overview

This document provides the technical implementation details for Prime Youth, including bounded contexts, ports & adapters architecture, and Elixir/Phoenix code examples. This builds upon the business domain stories defined in [domain-stories.md](./domain-stories.md).

## Bounded Contexts

### 1. **Program Catalog Context**
**Purpose:** Manages program discovery, details, and availability
**Core Concepts:** Program, School, Category, Schedule, Capacity, Pricing

**Responsibilities:**

- Program search and filtering
- Availability tracking
- Pricing management
- School program associations

### 2. **Enrollment Context**
**Purpose:** Handles the enrollment process from selection to payment
**Core Concepts:** Enrollment, Child, Parent, SpecialRequirements, Payment

**Responsibilities:**

- Child selection for programs
- Special requirements collection
- Payment processing
- Enrollment confirmation

### 3. **Family Management Context**
**Purpose:** Manages family data, children, and relationships
**Core Concepts:** Family, Parent, Child, Profile

**Responsibilities:**

- Family profile management
- Child information
- Parent-child relationships
- Profile updates

### 4. **Progress Tracking Context**
**Purpose:** Tracks child progress and family achievements
**Core Concepts:** Session, Progress, Achievement, Milestone

**Responsibilities:**

- Session attendance tracking
- Progress calculation
- Achievement unlocking
- Milestone progression

### 5. **Review & Rating Context**
**Purpose:** Manages program reviews and parent feedback
**Core Concepts:** Review, Rating, Verification, Parent

**Responsibilities:**

- Review collection
- Parent verification
- Rating aggregation
- Review moderation

## Ports & Adapters Architecture Examples

### Program Catalog Context Architecture

```
┌─────────────────────────────────────────────┐
│               Application Core              │
│  ┌─────────────────────────────────────┐   │
│  │         Program Domain              │   │
│  │  • Program Entity                   │   │
│  │  • School Value Object              │   │
│  │  • Capacity Value Object            │   │
│  │  • ProgramRepository Port           │   │
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │           Use Cases                 │   │
│  │  • DiscoverProgramsUseCase          │   │
│  │  • FilterProgramsUseCase            │   │
│  │  • ViewProgramDetailsUseCase        │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
                     │
    ┌────────────────┼────────────────┐
    │                │                │
┌───▼────┐    ┌─────▼─────┐    ┌─────▼─────┐
│  Web   │    │   Repo    │    │   Event   │
│Adapter │    │ Adapter   │    │ Adapter   │
│        │    │           │    │           │
│Phoenix │    │Ecto/Postgres│  │ EventBus  │
│Router  │    │           │    │           │
└────────┘    └───────────┘    └───────────┘
```

**Ports (Interfaces):**

- `ProgramRepository` - For data persistence
- `ProgramEventPublisher` - For domain events
- `SchoolService` - For school data integration

**Adapters (Implementations):**

- `EctoProgramRepository` - PostgreSQL via Ecto
- `PhoenixWebAdapter` - HTTP/JSON API
- `EventBusAdapter` - Internal event publishing

## Use Cases Mapped to Domain Stories

### Story 1: Parent Program Discovery
**Actors:** Parent, System, School

**Activities → Use Cases:**

- Parent [views] Programs → `DiscoverProgramsUseCase`
- Parent [filters] Programs → `FilterProgramsUseCase`
- Parent [searches] Programs → `SearchProgramsUseCase`
- System [shows] Program details → `ViewProgramDetailsUseCase`

### Story 2: Program Enrollment
**Actors:** Parent, Child, Program, Payment System

**Activities → Use Cases:**

- Parent [selects] Program → `SelectProgramForChildUseCase`
- System [shows] reviews → `ViewProgramReviewsUseCase`
- Parent [fills] form → `FillEnrollmentFormUseCase`
- System [calculates] cost → `CalculateEnrollmentCostUseCase`
- Parent [completes] payment → `ProcessEnrollmentPaymentUseCase`
- System [confirms] enrollment → `ConfirmEnrollmentUseCase`

### Story 3: Family Progress Tracking
**Actors:** Parent, Children, System, Achievements

**Activities → Use Cases:**

- Parent [opens] dashboard → `ViewFamilyDashboardUseCase`
- System [displays] progress → `TrackChildProgressUseCase`
- System [calculates] milestones → `CalculateFamilyMilestonesUseCase`
- Parent [views] recommendations → `RecommendNextProgramsUseCase`

## Elixir/Phoenix Implementation Examples

### Program Entity (Domain)

```elixir
# lib/prime_youth/program_catalog/program.ex
defmodule PrimeYouth.ProgramCatalog.Program do
  @enforce_keys [:id, :name, :school_id, :category, :age_range, :schedule, :pricing]
  defstruct [
    :id,
    :name,
    :description,
    :school_id,
    :category,
    :age_range,
    :schedule,
    :pricing,
    :capacity,
    :enrolled_count
  ]

  alias PrimeYouth.ProgramCatalog.{Schedule, Pricing, Capacity, AgeRange}

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    description: String.t() | nil,
    school_id: String.t(),
    category: atom(),
    age_range: AgeRange.t(),
    schedule: Schedule.t(),
    pricing: Pricing.t(),
    capacity: Capacity.t(),
    enrolled_count: non_neg_integer()
  }

  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  def available_spots(%__MODULE__{capacity: capacity, enrolled_count: enrolled}) do
    Capacity.available_spots(capacity, enrolled)
  end

  def is_available_for_age?(%__MODULE__{age_range: age_range}, child_age) do
    AgeRange.includes?(age_range, child_age)
  end
end
```

### Repository Port (Domain Interface)

```elixir
# lib/prime_youth/program_catalog/ports/program_repository.ex
defmodule PrimeYouth.ProgramCatalog.Ports.ProgramRepository do
  alias PrimeYouth.ProgramCatalog.Program

  @callback find_by_id(String.t()) :: {:ok, Program.t()} | {:error, :not_found}
  @callback find_by_school(String.t()) :: {:ok, [Program.t()]} | {:error, term()}
  @callback find_by_category(atom()) :: {:ok, [Program.t()]} | {:error, term()}
  @callback search(String.t()) :: {:ok, [Program.t()]} | {:error, term()}
  @callback save(Program.t()) :: {:ok, Program.t()} | {:error, term()}
end
```

### Repository Adapter (Infrastructure)

```elixir
# lib/prime_youth/program_catalog/adapters/ecto_program_repository.ex
defmodule PrimeYouth.ProgramCatalog.Adapters.EctoProgramRepository do
  @behaviour PrimeYouth.ProgramCatalog.Ports.ProgramRepository

  alias PrimeYouth.Repo
  alias PrimeYouth.ProgramCatalog.{Program, Schemas.ProgramSchema}

  @impl true
  def find_by_id(id) do
    case Repo.get(ProgramSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_domain(schema)}
    end
  end

  @impl true
  def find_by_school(school_id) do
    programs =
      ProgramSchema
      |> Ecto.Query.where([p], p.school_id == ^school_id)
      |> Repo.all()
      |> Enum.map(&to_domain/1)

    {:ok, programs}
  end

  @impl true
  def search(query) do
    programs =
      ProgramSchema
      |> Ecto.Query.where([p], ilike(p.name, ^"%#{query}%"))
      |> Repo.all()
      |> Enum.map(&to_domain/1)

    {:ok, programs}
  end

  defp to_domain(%ProgramSchema{} = schema) do
    Program.new(%{
      id: schema.id,
      name: schema.name,
      description: schema.description,
      school_id: schema.school_id,
      category: String.to_atom(schema.category),
      age_range: parse_age_range(schema.age_range),
      schedule: parse_schedule(schema.schedule),
      pricing: parse_pricing(schema.pricing),
      capacity: parse_capacity(schema.capacity),
      enrolled_count: schema.enrolled_count
    })
  end
end
```

### Use Cases

```elixir
# lib/prime_youth/program_catalog/use_cases/discover_programs_use_case.ex
defmodule PrimeYouth.ProgramCatalog.UseCases.DiscoverProgramsUseCase do
  alias PrimeYouth.ProgramCatalog.{Program, Ports.ProgramRepository}

  def execute(school_id, child_age) do
    repo = Application.get_env(:prime_youth, :program_repository)

    with {:ok, programs} <- repo.find_by_school(school_id) do
      available_programs =
        programs
        |> Enum.filter(&(Program.available_spots(&1) > 0))
        |> Enum.filter(&Program.is_available_for_age?(&1, child_age))

      {:ok, available_programs}
    end
  end
end

# lib/prime_youth/program_catalog/use_cases/filter_programs_use_case.ex
defmodule PrimeYouth.ProgramCatalog.UseCases.FilterProgramsUseCase do
  alias PrimeYouth.ProgramCatalog.Ports.ProgramRepository

  def execute(category) when is_atom(category) do
    repo = Application.get_env(:prime_youth, :program_repository)
    repo.find_by_category(category)
  end

  def execute(_), do: {:error, :invalid_category}
end

# lib/prime_youth/program_catalog/use_cases/search_programs_use_case.ex
defmodule PrimeYouth.ProgramCatalog.UseCases.SearchProgramsUseCase do
  alias PrimeYouth.ProgramCatalog.Ports.ProgramRepository

  def execute(query) when is_binary(query) and byte_size(query) > 0 do
    repo = Application.get_env(:prime_youth, :program_repository)
    repo.search(query)
  end

  def execute(_), do: {:error, :invalid_search_query}
end
```

### Phoenix Web Adapter

```elixir
# lib/prime_youth_web/controllers/program_controller.ex
defmodule PrimeYouthWeb.ProgramController do
  use PrimeYouthWeb, :controller

  alias PrimeYouth.ProgramCatalog.UseCases.{
    DiscoverProgramsUseCase,
    FilterProgramsUseCase,
    SearchProgramsUseCase
  }

  def index(conn, %{"school_id" => school_id, "child_age" => child_age}) do
    case DiscoverProgramsUseCase.execute(school_id, String.to_integer(child_age)) do
      {:ok, programs} ->
        render(conn, "index.json", programs: programs)

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  def index(conn, %{"category" => category}) do
    case FilterProgramsUseCase.execute(String.to_atom(category)) do
      {:ok, programs} ->
        render(conn, "index.json", programs: programs)

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  def index(conn, %{"query" => query}) do
    case SearchProgramsUseCase.execute(query) do
      {:ok, programs} ->
        render(conn, "index.json", programs: programs)

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  def show(conn, %{"id" => id}) do
    repo = Application.get_env(:prime_youth, :program_repository)

    case repo.find_by_id(id) do
      {:ok, program} ->
        render(conn, "show.json", program: program)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Program not found"})
    end
  end
end
```

### Configuration

```elixir
# config/config.exs
config :prime_youth,
  program_repository: PrimeYouth.ProgramCatalog.Adapters.EctoProgramRepository

# config/test.exs
config :prime_youth,
  program_repository: PrimeYouth.ProgramCatalog.Adapters.InMemoryProgramRepository
```

## Key Benefits of This Architecture

1. **Domain-Driven Design**: Clear bounded contexts reflect real business domains
2. **Testability**: Ports allow easy mocking and testing of business logic
3. **Flexibility**: Adapters can be swapped without changing core business logic
4. **Maintainability**: Clear separation of concerns and dependency inversion
5. **Domain Events**: Easy to add event sourcing and CQRS patterns later

## Next Steps

1. Implement remaining bounded contexts (Enrollment, Family Management, etc.)
2. Add domain events for cross-context communication
3. Implement CQRS for read/write separation
4. Add integration tests for adapter implementations
5. Create Phoenix channels for real-time updates

---

*This technical implementation supports the business domain stories defined in [domain-stories.md](./domain-stories.md)*