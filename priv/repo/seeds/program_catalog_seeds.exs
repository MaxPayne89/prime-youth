# Program Catalog Seeds
# Create sample data for testing the Browse and Discover Programs feature

alias PrimeYouth.Repo
alias PrimeYouth.Accounts.User
alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.{Provider, Program, Location, ProgramSchedule}

IO.puts("Seeding Program Catalog data...")

# Create or get existing test user
user =
  case Repo.get_by(User, email: "provider@example.com") do
    nil ->
      {:ok, user} =
        %User{}
        |> User.registration_changeset(%{
          email: "provider@example.com",
          password: "provider123456",
          name: "Test Provider"
        })
        |> Repo.insert()

      user

    existing_user ->
      existing_user
  end

# Create or get existing provider
provider =
  case Repo.get_by(Provider, email: "sports@primeyouth.com") do
    nil ->
      provider_attrs = %{
        name: "Prime Youth Sports Academy",
        description: "Leading sports education provider for youth in the Bay Area",
        email: "sports@primeyouth.com",
        phone: "(415) 555-0123",
        website: "https://primeyouthsports.com",
        credentials: "Certified Youth Sports Organization",
        is_verified: true,
        is_prime_youth: true,
        user_id: user.id
      }

      {:ok, provider} =
        %Provider{}
        |> Provider.changeset(provider_attrs)
        |> Repo.insert()

      IO.puts("Created provider: #{provider.name}")
      provider

    existing_provider ->
      IO.puts("Using existing provider: #{existing_provider.name}")
      existing_provider
  end

# Create sample programs with nested associations
programs_data = [
  %{
    title: "Soccer Fundamentals",
    description: "Learn the basics of soccer including dribbling, passing, and teamwork. Perfect for beginners who want to explore the beautiful game!",
    category: "sports",
    secondary_categories: ["team_sports", "outdoor"],
    age_min: 6,
    age_max: 10,
    capacity: 20,
    price_amount: Decimal.new("150.00"),
    price_unit: "session",
    status: "approved",
    is_prime_youth: true,
    featured: true,
    locations: [
      %{
        name: "Greenwood Elementary Field",
        address_line1: "123 Main Street",
        city: "San Francisco",
        state: "CA",
        postal_code: "94102",
        country: "USA",
        is_virtual: false
      }
    ],
    schedules: [
      %{
        start_date: ~D[2024-03-01],
        end_date: ~D[2024-06-01],
        days_of_week: ["monday", "wednesday"],
        start_time: ~T[15:00:00],
        end_time: ~T[16:30:00],
        recurrence_pattern: "weekly",
        session_count: 24
      }
    ]
  },
  %{
    title: "Basketball Skills Camp",
    description: "Develop your basketball skills with professional coaching. Focus on shooting, defense, and game strategy.",
    category: "sports",
    secondary_categories: ["team_sports", "indoor"],
    age_min: 8,
    age_max: 14,
    capacity: 16,
    price_amount: Decimal.new("200.00"),
    price_unit: "program",
    status: "approved",
    is_prime_youth: true,
    featured: false,
    locations: [
      %{
        name: "Community Sports Center",
        address_line1: "456 Oak Avenue",
        city: "Oakland",
        state: "CA",
        postal_code: "94607",
        country: "USA",
        is_virtual: false
      }
    ],
    schedules: [
      %{
        start_date: ~D[2024-03-15],
        end_date: ~D[2024-05-15],
        days_of_week: ["tuesday", "thursday"],
        start_time: ~T[16:00:00],
        end_time: ~T[17:30:00],
        recurrence_pattern: "weekly",
        session_count: 16
      }
    ]
  },
  %{
    title: "Creative Art Studio",
    description: "Explore various art mediums including painting, drawing, and sculpture. Unleash your creativity in a supportive environment!",
    category: "arts",
    secondary_categories: ["visual_arts", "creative"],
    age_min: 5,
    age_max: 12,
    capacity: 15,
    price_amount: Decimal.new("0.00"),
    price_unit: "program",
    status: "approved",
    is_prime_youth: false,
    featured: true,
    locations: [
      %{
        name: "Art Haven Studio",
        address_line1: "789 Pine Street",
        city: "San Francisco",
        state: "CA",
        postal_code: "94103",
        country: "USA",
        is_virtual: false
      }
    ],
    schedules: [
      %{
        start_date: ~D[2024-04-01],
        end_date: ~D[2024-06-30],
        days_of_week: ["saturday"],
        start_time: ~T[10:00:00],
        end_time: ~T[12:00:00],
        recurrence_pattern: "weekly",
        session_count: 12
      }
    ]
  },
  %{
    title: "Online Coding for Kids",
    description: "Learn programming basics through fun projects and games. Perfect introduction to coding for young learners!",
    category: "stem",
    secondary_categories: ["technology", "computer_science"],
    age_min: 8,
    age_max: 14,
    capacity: 25,
    price_amount: Decimal.new("175.00"),
    price_unit: "program",
    status: "approved",
    is_prime_youth: true,
    featured: false,
    locations: [
      %{
        name: "Virtual Classroom",
        is_virtual: true,
        virtual_link: "https://zoom.us/j/example"
      }
    ],
    schedules: [
      %{
        start_date: ~D[2024-03-20],
        end_date: ~D[2024-05-20],
        days_of_week: ["wednesday", "friday"],
        start_time: ~T[17:00:00],
        end_time: ~T[18:00:00],
        recurrence_pattern: "weekly",
        session_count: 16
      }
    ]
  },
  %{
    title: "Music Explorers",
    description: "Introduction to music through singing, rhythm, and simple instruments. A joyful musical journey for young children!",
    category: "music",
    secondary_categories: ["performance", "creative"],
    age_min: 4,
    age_max: 7,
    capacity: 12,
    price_amount: Decimal.new("120.00"),
    price_unit: "month",
    status: "approved",
    is_prime_youth: false,
    featured: false,
    locations: [
      %{
        name: "Harmony Music School",
        address_line1: "321 Maple Drive",
        city: "Berkeley",
        state: "CA",
        postal_code: "94704",
        country: "USA",
        is_virtual: false
      }
    ],
    schedules: [
      %{
        start_date: ~D[2024-03-10],
        end_date: ~D[2024-06-10],
        days_of_week: ["saturday"],
        start_time: ~T[09:00:00],
        end_time: ~T[10:00:00],
        recurrence_pattern: "weekly",
        session_count: 14
      }
    ]
  }
]

# Insert programs with nested associations using cast_assoc
for program_data <- programs_data do
  program_attrs = Map.put(program_data, :provider_id, provider.id)

  # Check if program already exists
  case Repo.get_by(Program, title: program_attrs.title, provider_id: provider.id) do
    nil ->
      {:ok, program} =
        %Program{}
        |> Program.changeset(program_attrs)
        |> Repo.insert()

      IO.puts("Created program: #{program.title}")

    _existing_program ->
      IO.puts("Program already exists: #{program_attrs.title}")
  end
end

IO.puts("✅ Program Catalog seeding complete!")
