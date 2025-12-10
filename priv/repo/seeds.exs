# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     PrimeYouth.Repo.insert!(%PrimeYouth.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias PrimeYouth.Accounts.User
alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
alias PrimeYouth.Repo

require Logger

# Test Users
Logger.info("Seeding test users...")

# Clear existing users to ensure idempotent seeding
Repo.delete_all(User)
Logger.info("Cleared existing users")

test_users = [
  %{
    name: "Max Pergl",
    email: "maxpergl@gmail.com",
    hashed_password: Bcrypt.hash_pwd_salt("password"),
    confirmed_at: DateTime.utc_now(:second)
  },
  %{
    name: "Prime Youth Admin",
    email: "app@primeyouth.de",
    hashed_password: Bcrypt.hash_pwd_salt("password"),
    confirmed_at: DateTime.utc_now(:second)
  }
]

Enum.each(test_users, fn user_attrs ->
  %User{}
  |> Ecto.Changeset.change(user_attrs)
  |> Repo.insert!()
end)

Logger.info("Seeded #{length(test_users)} test users successfully")

# Program Catalog Seeds
# Reference: specs/001-program-catalog/data-model.md (Sample Data section)

Logger.info("Seeding Program Catalog...")

# Clear existing programs to ensure idempotent seeding
Repo.delete_all(ProgramSchema)
Logger.info("Cleared existing programs")

programs = [
  %{
    title: "Art Adventures",
    description: "Explore creativity through painting, drawing, and crafts",
    schedule: "Mon-Fri, 3:00-5:00 PM",
    age_range: "6-8 years",
    price: Decimal.new("120.00"),
    pricing_period: "per month",
    spots_available: 12,
    gradient_class: "from-purple-500 to-pink-500",
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
    gradient_class: "from-blue-500 to-cyan-500",
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
    gradient_class: "from-green-500 to-emerald-500",
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
    gradient_class: "from-orange-500 to-red-500",
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
    gradient_class: "from-indigo-500 to-purple-500",
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
    gradient_class: "from-pink-500 to-rose-500",
    icon_path: "/images/icons/drama.svg"
  }
]

Enum.each(programs, fn program_attrs ->
  %ProgramSchema{}
  |> ProgramSchema.changeset(program_attrs)
  |> Repo.insert!()
end)

Logger.info("Seeded #{length(programs)} programs successfully")
Logger.info("Program Catalog seeding complete!")
