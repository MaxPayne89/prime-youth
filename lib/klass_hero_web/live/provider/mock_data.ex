defmodule KlassHeroWeb.Provider.MockData do
  @moduledoc """
  Hardcoded mock data for the provider dashboard.
  This module will be replaced with actual database queries later.
  """
  use Gettext, backend: KlassHeroWeb.Gettext

  @doc """
  Returns mock business profile data.
  """
  def business do
    %{
      id: 1,
      name: "Berlin Kickers",
      tagline: gettext("Professional Youth Soccer Coaching"),
      plan: :business,
      plan_label: gettext("Business Plan"),
      verified: true,
      verification_badges: [
        %{key: :business_registration, label: gettext("Business Registration")},
        %{key: :insurance, label: gettext("Insurance")}
      ],
      program_slots_used: 6,
      program_slots_total: nil,
      initials: "BK"
    }
  end

  @doc """
  Returns mock stats data.
  """
  def stats do
    %{
      total_revenue: 12_500,
      active_bookings: 45,
      profile_views: 1_205,
      average_rating: 4.9
    }
  end

  @doc """
  Returns mock team members.
  """
  def team do
    [
      %{
        id: 1,
        name: "Coach Mike",
        role: gettext("Head Coach"),
        email: "mike@berlinkickers.de",
        bio: gettext("Former Bundesliga youth player with 10 years coaching experience."),
        certifications: [gettext("UEFA B License"), gettext("First Aid")],
        hourly_rate: 45,
        initials: "CM"
      },
      %{
        id: 2,
        name: "Sarah L.",
        role: gettext("Assistant"),
        email: "sarah@berlinkickers.de",
        bio: gettext("Specializes in early childhood development and fun movement."),
        certifications: [gettext("Child Care Cert"), gettext("Safeguarding")],
        hourly_rate: 30,
        initials: "SL"
      }
    ]
  end

  @doc """
  Returns mock programs.
  """
  def programs do
    [
      %{
        id: 1,
        name: "Junior Soccer Academy",
        category: gettext("Sports"),
        price: 15,
        assigned_staff: %{id: 1, name: "Coach Mike", initials: "CM"},
        status: :active,
        enrolled: 16,
        capacity: 20
      },
      %{
        id: 2,
        name: "Creative Art Workshop",
        category: gettext("Arts"),
        price: 25,
        assigned_staff: %{id: 2, name: "Sarah L.", initials: "SL"},
        status: :active,
        enrolled: 8,
        capacity: 12
      },
      %{
        id: 3,
        name: "Math Whiz Tutoring",
        category: gettext("Education"),
        price: 30,
        assigned_staff: nil,
        status: :active,
        enrolled: 2,
        capacity: 1
      },
      %{
        id: 4,
        name: "Summer Adventure Camp",
        category: gettext("Camps"),
        price: 250,
        assigned_staff: nil,
        status: :active,
        enrolled: 24,
        capacity: 40
      },
      %{
        id: 5,
        name: "Piano for Beginners",
        category: gettext("Music"),
        price: 40,
        assigned_staff: nil,
        status: :active,
        enrolled: 4,
        capacity: 5
      },
      %{
        id: 6,
        name: "Weekend Babysitting",
        category: gettext("Life Skills"),
        price: 18,
        assigned_staff: nil,
        status: :active,
        enrolled: 0,
        capacity: 1
      }
    ]
  end

  @doc """
  Returns mock weekly schedule.
  """
  def weekly_schedule do
    [
      %{day: :monday, programs: []},
      %{
        day: :tuesday,
        programs: [%{name: "Junior Soccer Academy", time: "16:00"}]
      },
      %{
        day: :wednesday,
        programs: [%{name: "Creative Art Workshop", time: "15:30"}]
      },
      %{
        day: :thursday,
        programs: [%{name: "Piano for Beginners", time: "14:00"}]
      },
      %{day: :friday, programs: []},
      %{day: :saturday, programs: []},
      %{day: :sunday, programs: []}
    ]
  end

  @doc """
  Returns staff options for dropdown filters.
  """
  def staff_options do
    [
      %{value: "all", label: gettext("All Staff")},
      %{value: "1", label: "Coach Mike"},
      %{value: "2", label: "Sarah L."}
    ]
  end
end
