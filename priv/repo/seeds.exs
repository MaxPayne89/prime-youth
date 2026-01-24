# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     KlassHero.Repo.insert!(%KlassHero.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias KlassHero.Accounts.User
alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ChildSchema
alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ParentProfileSchema
alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
alias KlassHero.Repo

require Logger

# ==============================================================================
# CLEAR EXISTING DATA
# ==============================================================================

Logger.info("Clearing existing data...")

# Order matters due to foreign key constraints
Repo.delete_all(ChildSchema)
Logger.info("Cleared existing children")

Repo.delete_all(ParentProfileSchema)
Logger.info("Cleared existing parent profiles")

Repo.delete_all(ProviderProfileSchema)
Logger.info("Cleared existing provider profiles")

Repo.delete_all(User)
Logger.info("Cleared existing users")

Repo.delete_all(ProgramSchema)
Logger.info("Cleared existing programs")

# ==============================================================================
# CREATE USERS
# ==============================================================================

Logger.info("Seeding users...")

# ==============================================================================
# PARENT USERS (2 users - one per tier)
# ==============================================================================

# Max Explorer - Parent user (explorer tier - cannot initiate messages)
{:ok, max_explorer} =
  %User{}
  |> Ecto.Changeset.change(%{
    name: "Max Explorer",
    email: "maxpergl-1@gmail.com",
    hashed_password: Bcrypt.hash_pwd_salt("password"),
    confirmed_at: DateTime.utc_now(:second),
    intended_roles: [:parent]
  })
  |> Repo.insert()

Logger.info("Created Max Explorer as parent user (explorer tier)")

# Max Active - Parent user (active tier - can initiate messages)
{:ok, max_active} =
  %User{}
  |> Ecto.Changeset.change(%{
    name: "Max Active",
    email: "maxpergl-2@gmail.com",
    hashed_password: Bcrypt.hash_pwd_salt("password"),
    confirmed_at: DateTime.utc_now(:second),
    intended_roles: [:parent]
  })
  |> Repo.insert()

Logger.info("Created Max Active as parent user (active tier)")

# ==============================================================================
# PROVIDER USERS (3 users - one per tier)
# ==============================================================================

# Shane Starter - Provider user (starter tier - cannot initiate messages)
{:ok, shane_starter} =
  %User{}
  |> Ecto.Changeset.change(%{
    name: "Shane Starter",
    email: "shane.provider-1@gmail.com",
    hashed_password: Bcrypt.hash_pwd_salt("password"),
    confirmed_at: DateTime.utc_now(:second),
    intended_roles: [:provider]
  })
  |> Repo.insert()

Logger.info("Created Shane Starter as provider user (starter tier)")

# Shane Professional - Provider user (professional tier - can initiate messages)
{:ok, shane_professional} =
  %User{}
  |> Ecto.Changeset.change(%{
    name: "Shane Professional",
    email: "shane.provider-2@gmail.com",
    hashed_password: Bcrypt.hash_pwd_salt("password"),
    confirmed_at: DateTime.utc_now(:second),
    intended_roles: [:provider]
  })
  |> Repo.insert()

Logger.info("Created Shane Professional as provider user (professional tier)")

# Shane Business Plus - Provider user (business_plus tier - can initiate messages)
{:ok, shane_business_plus} =
  %User{}
  |> Ecto.Changeset.change(%{
    name: "Shane Business Plus",
    email: "shane.provider-3@gmail.com",
    hashed_password: Bcrypt.hash_pwd_salt("password"),
    confirmed_at: DateTime.utc_now(:second),
    intended_roles: [:provider]
  })
  |> Repo.insert()

Logger.info("Created Shane Business Plus as provider user (business_plus tier)")

# Admin user (kept for admin purposes)
{:ok, _admin} =
  %User{}
  |> Ecto.Changeset.change(%{
    name: "Klass Hero Admin",
    email: "app@primeyouth.de",
    hashed_password: Bcrypt.hash_pwd_salt("password"),
    confirmed_at: DateTime.utc_now(:second)
  })
  |> Repo.insert()

Logger.info("Created admin user")

# ==============================================================================
# CREATE PARENT PROFILES & CHILDREN
# ==============================================================================

Logger.info("Creating parent profiles...")

# Calculate dates for children
today = Date.utc_today()
tj_birth_date = Date.add(today, -365 * 8)
rafael_birth_date = Date.add(today, -365 * 6)

# --- Max Explorer (explorer tier) ---
{:ok, max_explorer_profile} =
  %ParentProfileSchema{}
  |> ParentProfileSchema.changeset(%{
    identity_id: max_explorer.id,
    display_name: "Max E.",
    phone: "+49 123 456 7890",
    location: "Berlin, Germany",
    subscription_tier: "explorer"
  })
  |> Repo.insert()

Logger.info("Created parent profile for Max Explorer (explorer tier)")

# Children for Max Explorer
{:ok, _tj_1} =
  %ChildSchema{}
  |> ChildSchema.changeset(%{
    parent_id: max_explorer_profile.id,
    first_name: "TJ",
    last_name: "Explorer",
    date_of_birth: tj_birth_date,
    notes: "Loves sports and outdoor activities"
  })
  |> Repo.insert()

Logger.info("Created child: TJ Explorer (8 years old) for Max Explorer")

{:ok, _rafael_1} =
  %ChildSchema{}
  |> ChildSchema.changeset(%{
    parent_id: max_explorer_profile.id,
    first_name: "Rafael",
    last_name: "Explorer",
    date_of_birth: rafael_birth_date,
    notes: "Enjoys arts and crafts"
  })
  |> Repo.insert()

Logger.info("Created child: Rafael Explorer (6 years old) for Max Explorer")

# --- Max Active (active tier) ---
{:ok, max_active_profile} =
  %ParentProfileSchema{}
  |> ParentProfileSchema.changeset(%{
    identity_id: max_active.id,
    display_name: "Max A.",
    phone: "+49 123 456 7891",
    location: "Munich, Germany",
    subscription_tier: "active"
  })
  |> Repo.insert()

Logger.info("Created parent profile for Max Active (active tier)")

# Children for Max Active
{:ok, _tj_2} =
  %ChildSchema{}
  |> ChildSchema.changeset(%{
    parent_id: max_active_profile.id,
    first_name: "TJ",
    last_name: "Active",
    date_of_birth: tj_birth_date,
    notes: "Loves technology and coding"
  })
  |> Repo.insert()

Logger.info("Created child: TJ Active (8 years old) for Max Active")

{:ok, _rafael_2} =
  %ChildSchema{}
  |> ChildSchema.changeset(%{
    parent_id: max_active_profile.id,
    first_name: "Rafael",
    last_name: "Active",
    date_of_birth: rafael_birth_date,
    notes: "Enjoys music and dance"
  })
  |> Repo.insert()

Logger.info("Created child: Rafael Active (6 years old) for Max Active")

# ==============================================================================
# CREATE PROVIDER PROFILES
# ==============================================================================

Logger.info("Creating provider profiles...")

# --- Shane Starter (starter tier) ---
{:ok, _shane_starter_profile} =
  %ProviderProfileSchema{}
  |> ProviderProfileSchema.changeset(%{
    identity_id: shane_starter.id,
    business_name: "Shane's Starter Academy",
    description: "Entry-level sports training for youth",
    phone: "+49 987 654 3210",
    website: "https://shanes-starter-academy.example.com",
    address: "123 Beginner Street, Munich, Germany",
    verified: true,
    verified_at: DateTime.utc_now(:second),
    categories: ["Sports", "Fitness"],
    subscription_tier: "starter"
  })
  |> Repo.insert()

Logger.info("Created provider profile for Shane's Starter Academy (starter tier)")

# --- Shane Professional (professional tier) ---
{:ok, _shane_professional_profile} =
  %ProviderProfileSchema{}
  |> ProviderProfileSchema.changeset(%{
    identity_id: shane_professional.id,
    business_name: "Shane's Pro Academy",
    description: "Professional sports training and athletic development for youth",
    phone: "+49 987 654 3211",
    website: "https://shanes-pro-academy.example.com",
    address: "456 Pro Avenue, Munich, Germany",
    verified: true,
    verified_at: DateTime.utc_now(:second),
    categories: ["Sports", "Athletics", "Physical Education"],
    subscription_tier: "professional"
  })
  |> Repo.insert()

Logger.info("Created provider profile for Shane's Pro Academy (professional tier)")

# --- Shane Business Plus (business_plus tier) ---
{:ok, _shane_business_plus_profile} =
  %ProviderProfileSchema{}
  |> ProviderProfileSchema.changeset(%{
    identity_id: shane_business_plus.id,
    business_name: "Shane's Elite Academy",
    description: "Elite sports training, camps, and comprehensive youth development programs",
    phone: "+49 987 654 3212",
    website: "https://shanes-elite-academy.example.com",
    address: "789 Elite Boulevard, Munich, Germany",
    verified: true,
    verified_at: DateTime.utc_now(:second),
    categories: ["Sports", "Athletics", "Physical Education", "Camps", "Elite Training"],
    subscription_tier: "business_plus"
  })
  |> Repo.insert()

Logger.info("Created provider profile for Shane's Elite Academy (business_plus tier)")

# ==============================================================================
# CREATE SAMPLE PROGRAMS
# ==============================================================================

Logger.info("Seeding Program Catalog...")

programs = [
  %{
    title: "Art Adventures",
    description: "Explore creativity through painting, drawing, and crafts",
    category: "arts",
    schedule: "Mon-Fri, 3:00-5:00 PM",
    age_range: "6-8 years",
    price: Decimal.new("120.00"),
    pricing_period: "per month",
    spots_available: 12,
    icon_path: "/images/icons/art.svg"
  },
  %{
    title: "Tech Explorers",
    description: "Learn coding, robotics, and digital creation",
    category: "education",
    schedule: "Tue/Thu, 4:00-6:00 PM",
    age_range: "9-12 years",
    price: Decimal.new("150.00"),
    pricing_period: "per month",
    spots_available: 8,
    icon_path: "/images/icons/tech.svg"
  },
  %{
    title: "Sports Camp",
    description: "Multi-sport activities including soccer, basketball, and more",
    category: "sports",
    schedule: "Mon-Fri, 9:00 AM-3:00 PM",
    age_range: "7-14 years",
    price: Decimal.new("200.00"),
    pricing_period: "per week",
    spots_available: 20,
    icon_path: "/images/icons/sports.svg"
  },
  %{
    title: "Science Lab",
    description: "Hands-on experiments and STEM learning",
    category: "education",
    schedule: "Wed, 3:30-5:30 PM",
    age_range: "8-11 years",
    price: Decimal.new("100.00"),
    pricing_period: "per month",
    spots_available: 0,
    icon_path: "/images/icons/science.svg"
  },
  %{
    title: "Music Journey",
    description: "Learn instruments, singing, and music theory",
    category: "music",
    schedule: "Mon/Wed, 4:00-5:00 PM",
    age_range: "6-10 years",
    price: Decimal.new("130.00"),
    pricing_period: "per month",
    spots_available: 6,
    icon_path: "/images/icons/music.svg"
  },
  %{
    title: "Drama Club",
    description: "Acting, improvisation, and theatrical performances",
    category: "arts",
    schedule: "Fri, 3:00-5:00 PM",
    age_range: "8-13 years",
    price: Decimal.new("0.00"),
    pricing_period: "free",
    spots_available: 15,
    icon_path: "/images/icons/drama.svg"
  }
]

Enum.each(programs, fn program_attrs ->
  %ProgramSchema{}
  |> ProgramSchema.changeset(program_attrs)
  |> Repo.insert!()
end)

Logger.info("Seeded #{length(programs)} programs successfully")

# ==============================================================================
# SUMMARY
# ==============================================================================

Logger.info("Seeding complete!")
Logger.info("Summary:")
Logger.info("  - 6 users created:")
Logger.info("    - 2 parents: Max Explorer (explorer), Max Active (active)")

Logger.info(
  "    - 3 providers: Shane Starter (starter), Shane Professional (professional), Shane Business Plus (business_plus)"
)

Logger.info("    - 1 admin: Klass Hero Admin")
Logger.info("  - 2 parent profiles created with subscription tiers")
Logger.info("  - 4 children created (2 per parent)")
Logger.info("  - 3 provider profiles created with subscription tiers")
Logger.info("  - #{length(programs)} programs created")
