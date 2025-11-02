defmodule PrimeYouthWeb.Live.SampleFixtures do
  @moduledoc """
  Temporary sample data fixtures for LiveView development.

  This module centralizes all sample data used across LiveViews during development.
  Once domain contexts and database schemas are implemented, these fixtures should
  be replaced with real database queries.

  ## Usage

      import PrimeYouthWeb.Live.SampleFixtures

      def mount(_params, _session, socket) do
        socket
        |> assign(user: sample_user())
        |> assign(programs: sample_programs())
      end
  """

  # User Fixtures

  @doc """
  Returns a sample user for development and testing.
  """
  def sample_user do
    %{
      name: "Sarah Johnson",
      email: "sarah.johnson@example.com",
      avatar:
        "https://images.unsplash.com/photo-1494790108755-2616b612b388?w=64&h=64&fit=crop&crop=face",
      children_summary: "Emma (8), Liam (6)"
    }
  end

  # Children Fixtures

  @doc """
  Returns sample children data.

  ## Options

    * `:simple` - Basic children data with id, name, and age only
    * `:extended` - Full children data including school, sessions, progress, and activities

  Defaults to `:extended` if no option is provided.
  """
  def sample_children(variant \\ :extended)

  def sample_children(:simple) do
    [
      %{
        id: 1,
        name: "Emma Johnson",
        age: 8
      },
      %{
        id: 2,
        name: "Liam Johnson",
        age: 6
      }
    ]
  end

  def sample_children(:extended) do
    [
      %{
        id: 1,
        name: "Emma Johnson",
        age: 8,
        school: "Greenwood Elementary",
        sessions: "8/10",
        progress: 80,
        activities: ["Art", "Chess", "Swimming"]
      },
      %{
        id: 2,
        name: "Liam Johnson",
        age: 6,
        school: "Sunny Hills Kindergarten",
        sessions: "6/8",
        progress: 75,
        activities: ["Soccer", "Music"]
      }
    ]
  end

  # Program Fixtures

  @doc """
  Returns sample programs data.

  ## Options

    * `:basic` - Standard program data with basic fields (used in program lists)
    * `:detailed` - Extended program data including long descriptions and included items (used in detail pages)

  Defaults to `:basic` if no option is provided.
  """
  def sample_programs(variant \\ :basic)

  def sample_programs(:basic) do
    [
      %{
        id: 1,
        title: "Creative Art World",
        description:
          "Unleash your child's creativity through painting, drawing, sculpture, and mixed media projects. Each session explores different artistic techniques and mediums.",
        gradient_class: "bg-gradient-to-br from-orange-400 via-pink-500 to-purple-600",
        icon_path:
          "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v1.5L15 4l2 7-7 2.5V15a2 2 0 01-2 2z",
        schedule: "Wednesdays 4-6 PM",
        age_range: "6-12",
        price: 30,
        period: "per session",
        spots_left: 2
      },
      %{
        id: 2,
        title: "Chess Masters",
        description:
          "Learn strategic thinking and problem-solving through the ancient game of chess. Perfect for developing critical thinking skills and patience.",
        gradient_class: "bg-gradient-to-br from-gray-700 via-gray-800 to-black",
        icon_path:
          "M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z",
        schedule: "Mon, Wed 4-5 PM",
        age_range: "8-14",
        price: 25,
        period: "per session",
        spots_left: 5
      },
      %{
        id: 3,
        title: "Science Explorers",
        description:
          "Hands-on science experiments and discovery. Making learning fun through interactive activities and real-world applications.",
        gradient_class: "bg-gradient-to-br from-green-400 via-blue-500 to-purple-600",
        icon_path:
          "M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z",
        schedule: "Fri 4-5:30 PM",
        age_range: "7-11",
        price: 35,
        period: "per session",
        spots_left: 8
      },
      %{
        id: 4,
        title: "Soccer Skills",
        description:
          "Develop fundamental soccer skills including dribbling, passing, shooting, and teamwork. All skill levels welcome in a fun, supportive environment.",
        gradient_class: "bg-gradient-to-br from-green-500 via-emerald-600 to-teal-700",
        icon_path:
          "M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z",
        schedule: "Saturdays 10-11:30 AM",
        age_range: "5-10",
        price: 20,
        period: "per session",
        spots_left: 12
      },
      %{
        id: 5,
        title: "Music & Movement",
        description:
          "Introduction to music through singing, dancing, and simple instruments. Builds rhythm, coordination, and musical appreciation.",
        gradient_class: "bg-gradient-to-br from-pink-400 via-purple-500 to-indigo-600",
        icon_path:
          "M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z M21 16c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z",
        schedule: "Tuesdays 3:30-4:30 PM",
        age_range: "3-6",
        price: 28,
        period: "per session",
        spots_left: 6
      },
      %{
        id: 6,
        title: "Coding for Kids",
        description:
          "Introduction to programming concepts through fun, visual coding languages and games. Build logic skills and creativity.",
        gradient_class: "bg-gradient-to-br from-blue-500 via-indigo-600 to-purple-700",
        icon_path: "M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4",
        schedule: "Thursdays 5-6 PM",
        age_range: "8-12",
        price: 40,
        period: "per session",
        spots_left: 4
      }
    ]
  end

  def sample_programs(:detailed) do
    [
      %{
        id: 1,
        title: "Creative Art World",
        description:
          "Unleash your child's creativity through painting, drawing, sculpture, and mixed media projects.",
        long_description:
          "Unleash your child's creativity in our comprehensive art program! Students will explore various artistic mediums including painting, drawing, sculpting, and digital art. Our expert instructors guide each child to develop their unique artistic voice while building fundamental skills.",
        gradient_class: "bg-gradient-to-br from-yellow-400 via-orange-500 to-yellow-600",
        icon_path:
          "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v1.5L15 4l2 7-7 2.5V15a2 2 0 01-2 2z",
        schedule: "Wednesdays 4-6 PM",
        age_range: "6-12",
        price: 45,
        spots_left: 2,
        included_items: [
          "Professional art supplies and materials",
          "Small group instruction (max 8 students)",
          "Take-home art portfolio",
          "End-of-session showcase exhibition"
        ]
      },
      %{
        id: 2,
        title: "Chess Masters",
        description:
          "Learn strategic thinking and problem-solving through the ancient game of chess.",
        long_description:
          "Develop strategic thinking and problem-solving skills through the timeless game of chess. Perfect for developing critical thinking skills, patience, and logical reasoning in a fun, supportive environment.",
        gradient_class: "bg-gradient-to-br from-gray-700 via-gray-800 to-black",
        icon_path:
          "M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z",
        schedule: "Mon, Wed 4-5 PM",
        age_range: "8-14",
        price: 25,
        spots_left: 5,
        included_items: [
          "Chess set for each student",
          "Beginner to advanced curriculum",
          "Tournament preparation",
          "Chess notation workbook"
        ]
      }
    ]
  end

  @doc """
  Finds a program by its ID.
  Returns the program if found, or nil if not found.

  ## Parameters
    - id: Integer ID of the program to find

  ## Returns
    - Program map if found
    - nil if not found

  ## Examples
      iex> get_program_by_id(1)
      %{id: 1, title: "Creative Art World", ...}

      iex> get_program_by_id(999)
      nil

  Note: This function expects an integer ID. Callers should validate and parse
  the ID before calling this function.
  """
  def get_program_by_id(id) when is_integer(id) do
    programs = sample_programs(:detailed)
    Enum.find(programs, fn p -> p.id == id end)
  end

  @doc """
  Returns a list of featured programs for the home page.
  Currently returns the first two programs from the basic list.
  """
  def featured_programs do
    sample_programs(:basic) |> Enum.take(2)
  end

  # Instructor Fixtures

  @doc """
  Returns sample instructor data.
  """
  def sample_instructor do
    %{
      name: "Ms. Elena Rodriguez",
      credentials: "Master of Fine Arts, 8+ years teaching experience",
      bio:
        "Elena specializes in fostering creativity while building technical skills. Her students have won numerous local art competitions and developed lifelong passions for the arts.",
      avatar:
        "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=64&h=64&fit=crop&crop=face",
      rating: "4.9",
      review_count: 47
    }
  end

  # Review Fixtures

  @doc """
  Returns sample review data.
  """
  def sample_reviews do
    [
      %{
        comment:
          "My daughter Emma has grown so much in confidence and creativity. She can't wait for art class each week!",
        parent_name: "Sarah Johnson",
        parent_avatar:
          "https://images.unsplash.com/photo-1494790108755-2616b612b388?w=32&h=32&fit=crop&crop=face",
        child_name: "Emma",
        child_age: 8,
        verified: true
      },
      %{
        comment:
          "Excellent program with caring instructors. The small class size makes all the difference.",
        parent_name: "Michael Chen",
        parent_avatar:
          "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=32&h=32&fit=crop&crop=face",
        child_name: "Sophie",
        child_age: 7,
        verified: true
      },
      %{
        comment:
          "As a working parent, I appreciate the reliable schedule and professional communication. Max has made friends and learned techniques I never could have taught him at home.",
        parent_name: "Lisa Rodriguez",
        parent_avatar:
          "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=32&h=32&fit=crop&crop=face",
        child_name: "Max",
        child_age: 9,
        verified: true
      }
    ]
  end

  # Activity Fixtures

  @doc """
  Returns sample upcoming activities for the dashboard.
  """
  def sample_upcoming_activities do
    [
      %{
        id: 1,
        name: "Creative Art World",
        instructor: "Ms. Rodriguez",
        time: "Today, 4:00 PM",
        status: "Today",
        status_color: "bg-red-100 text-red-700"
      },
      %{
        id: 2,
        name: "Chess Masters",
        instructor: "Mr. Chen",
        time: "Tomorrow, 3:30 PM",
        status: "Tomorrow",
        status_color: "bg-orange-100 text-orange-700"
      },
      %{
        id: 3,
        name: "Swimming Lessons",
        instructor: "Coach Davis",
        time: "Friday, 2:00 PM",
        status: "This Week",
        status_color: "bg-blue-100 text-blue-700"
      }
    ]
  end

  # Helper Data Fixtures

  @doc """
  Returns filter options for the programs page.
  """
  def filter_options do
    [
      %{id: "all", label: "All Programs"},
      %{id: "available", label: "Available"},
      %{id: "ages", label: "By Age"},
      %{id: "price", label: "By Price"}
    ]
  end

  @doc """
  Returns core values for the about page.
  """
  def core_values do
    [
      %{
        icon_path:
          "M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z",
        title: "Safety First",
        description:
          "All instructors are background-checked and certified. We maintain strict child-to-instructor ratios and follow comprehensive safety protocols."
      },
      %{
        icon_path:
          "M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253",
        title: "Quality Learning",
        description:
          "Our curriculum is designed by education professionals and adapted to each child's pace. We focus on skill development through engaging, age-appropriate activities."
      },
      %{
        icon_path:
          "M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
        title: "Fun & Inclusive",
        description:
          "We believe learning should be enjoyable! Our positive, supportive environment welcomes children of all abilities and backgrounds."
      }
    ]
  end

  @doc """
  Returns key features for the about page.
  """
  def key_features do
    [
      %{title: "Flexible Scheduling", description: "Options to fit your family's busy life"},
      %{title: "Small Groups", description: "Maximum 8 students per instructor"},
      %{title: "Progress Tracking", description: "Regular updates on your child's development"},
      %{title: "Community Events", description: "Family activities and showcase opportunities"}
    ]
  end

  @doc """
  Returns statistics for the about page.
  """
  def stats do
    [
      %{value: "500+", label: "Happy Families"},
      %{value: "15+", label: "Expert Instructors"},
      %{value: "20+", label: "Programs Offered"},
      %{value: "5", label: "Years of Excellence"}
    ]
  end

  @doc """
  Returns contact methods for the contact page.
  """
  def contact_methods do
    [
      %{
        icon_path:
          "M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z",
        title: "Email Us",
        detail: "info@primeyouth.com",
        link: "mailto:info@primeyouth.com"
      },
      %{
        icon_path:
          "M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z",
        title: "Call Us",
        detail: "+1 (555) 123-4567",
        link: "tel:+15551234567"
      },
      %{
        icon_path:
          "M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z M15 11a3 3 0 11-6 0 3 3 0 016 0z",
        title: "Visit Us",
        detail: "123 Learning Lane, Cityville, ST 12345",
        link: nil
      }
    ]
  end

  @doc """
  Returns office hours for the contact page.
  """
  def office_hours do
    [
      %{day: "Monday - Friday", hours: "8:00 AM - 6:00 PM"},
      %{day: "Saturday", hours: "9:00 AM - 3:00 PM"},
      %{day: "Sunday", hours: "Closed"}
    ]
  end

  @doc """
  Returns subject options for the contact form.
  """
  def contact_subjects do
    ["General Inquiry", "Program Information", "Enrollment", "Feedback", "Other"]
  end
end
