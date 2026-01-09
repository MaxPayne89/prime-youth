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
alias KlassHero.Identity.Application.UseCases.Parents.CreateParentProfile
alias KlassHero.Identity.Application.UseCases.Providers.CreateProviderProfile
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

# Max - Parent user
{:ok, max} =
  %User{}
  |> Ecto.Changeset.change(%{
    name: "Max Pergl",
    email: "maxpergl@gmail.com",
    hashed_password: Bcrypt.hash_pwd_salt("password"),
    confirmed_at: DateTime.utc_now(:second),
    intended_roles: [:parent]
  })
  |> Repo.insert()

Logger.info("Created Max as parent user")

# Shane - Provider user
{:ok, shane} =
  %User{}
  |> Ecto.Changeset.change(%{
    name: "Shane Provider",
    email: "shane.provider@gmail.com",
    hashed_password: Bcrypt.hash_pwd_salt("password"),
    confirmed_at: DateTime.utc_now(:second),
    intended_roles: [:provider]
  })
  |> Repo.insert()

Logger.info("Created Shane as provider user")

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
# CREATE PARENT PROFILE & CHILDREN FOR MAX
# ==============================================================================

Logger.info("Creating parent profile for Max...")

# Create parent profile for Max
{:ok, max_parent_profile} =
  CreateParentProfile.execute(%{
    identity_id: max.id,
    display_name: "Max P.",
    phone: "+49 123 456 7890",
    location: "Berlin, Germany"
  })

Logger.info("Created parent profile for Max")

# Create children for Max
# Calculate dates for 8 and 6 year olds
today = Date.utc_today()
tj_birth_date = Date.add(today, -365 * 8)
rafael_birth_date = Date.add(today, -365 * 6)

# TJ - 8 years old
{:ok, _tj} =
  %ChildSchema{}
  |> ChildSchema.changeset(%{
    parent_id: max_parent_profile.id,
    first_name: "TJ",
    last_name: "Pergl",
    date_of_birth: tj_birth_date,
    notes: "Loves sports and outdoor activities"
  })
  |> Repo.insert()

Logger.info("Created child: TJ Pergl (8 years old)")

# Rafael - 6 years old
{:ok, _rafael} =
  %ChildSchema{}
  |> ChildSchema.changeset(%{
    parent_id: max_parent_profile.id,
    first_name: "Rafael",
    last_name: "Pergl",
    date_of_birth: rafael_birth_date,
    notes: "Enjoys arts and crafts"
  })
  |> Repo.insert()

Logger.info("Created child: Rafael Pergl (6 years old)")

# ==============================================================================
# CREATE PROVIDER PROFILE FOR SHANE
# ==============================================================================

Logger.info("Creating provider profile for Shane...")

{:ok, _shane_provider_profile} =
  CreateProviderProfile.execute(%{
    identity_id: shane.id,
    business_name: "Shane's Sports Academy",
    description: "Professional sports training and athletic development for youth",
    phone: "+49 987 654 3210",
    website: "https://shanes-sports-academy.example.com",
    address: "123 Sports Street, Munich, Germany",
    verified: true,
    verified_at: DateTime.utc_now(:second),
    categories: ["Sports", "Athletics", "Physical Education"]
  })

Logger.info("Created provider profile for Shane's Sports Academy")

# ==============================================================================
# CREATE SAMPLE PROGRAMS
# ==============================================================================

Logger.info("Seeding Program Catalog...")

programs = [
  %{
    title: "Art Adventures",
    description: "Explore creativity through painting, drawing, and crafts",
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

Logger.info("✅ Seeding complete!")
Logger.info("Summary:")
Logger.info("  - 3 users created (Max as parent, Shane as provider, Admin)")
Logger.info("  - 1 parent profile created (Max)")
Logger.info("  - 2 children created (TJ and Rafael)")
Logger.info("  - 1 provider profile created (Shane's Sports Academy)")
Logger.info("  - #{length(programs)} programs created")
