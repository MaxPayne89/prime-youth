defmodule KlassHeroWeb.ProgramDetailLive do
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.Live.SampleFixtures
  import KlassHeroWeb.ProgramComponents
  import KlassHeroWeb.ReviewComponents
  import KlassHeroWeb.UIComponents

  alias KlassHero.Enrollment
  alias KlassHero.ProgramCatalog
  alias KlassHero.Provider
  alias KlassHeroWeb.Presenters.ProgramPresenter
  alias KlassHeroWeb.Presenters.StaffMemberPresenter
  alias KlassHeroWeb.Theme

  @impl true
  def mount(%{"id" => program_id}, _session, socket) do
    case ProgramCatalog.get_program_by_id(program_id) do
      {:ok, program} ->
        # Add temporary included_items field (fixture data until proper implementation)
        program_with_items =
          Map.put(program, :included_items, [
            gettext("Weekly art supplies and materials"),
            gettext("Take-home projects every week"),
            gettext("Portfolio folder to track progress"),
            gettext("Final exhibition showcase")
          ])

        team_members = load_team_members(program.provider_id)

        participant_policy =
          case Enrollment.get_participant_policy(program.id) do
            {:ok, policy} -> policy
            {:error, :not_found} -> nil
          end

        socket =
          socket
          |> assign(page_title: program.title)
          |> assign(program: program_with_items)
          |> assign(team_members: team_members)
          |> assign(instructor: sample_instructor())
          |> assign(reviews: sample_reviews())
          |> assign(registration_status: ProgramCatalog.registration_status(program))
          |> assign(participant_policy: participant_policy)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(
           :error,
           gettext("Program not found. It may have been removed or is no longer available.")
         )
         |> redirect(to: ~p"/programs")}

      {:error, _error} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Unable to load program. Please try again later."))
         |> redirect(to: ~p"/programs")}
    end
  end

  @impl true
  def handle_event("back_to_programs", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/programs")}
  end

  @impl true
  def handle_event("toggle_favorite", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("enroll_now", _params, socket) do
    # Trigger: registration period is open (or always_open)
    # Why: prevent enrollment when registration is upcoming or closed
    # Outcome: navigates to booking page or shows error flash
    if ProgramCatalog.registration_open?(socket.assigns.program) do
      {:noreply, push_navigate(socket, to: ~p"/programs/#{socket.assigns.program.id}/booking")}
    else
      {:noreply, put_flash(socket, :error, gettext("Registration is not open for this program."))}
    end
  end

  @impl true
  def handle_event("save_for_later", _params, socket) do
    {:noreply, socket}
  end

  defp load_team_members(nil), do: []

  defp load_team_members(provider_id) do
    case Provider.list_staff_members(provider_id) do
      {:ok, members} -> StaffMemberPresenter.to_card_view_list(members)
      {:error, _} -> []
    end
  end

  defp registration_status_title(:upcoming, %{registration_period: %{start_date: start_date}}) do
    gettext("Registration opens %{date}", date: Calendar.strftime(start_date, "%B %d, %Y"))
  end

  defp registration_status_title(:closed, _program) do
    gettext("Registration is closed")
  end

  attr :id, :string, required: true
  attr :class, :string, default: ""
  attr :registration_status, :atom, required: true
  attr :label, :string, required: true

  defp enroll_button(assigns) do
    ~H"""
    <button
      id={@id}
      phx-click="enroll_now"
      disabled={@registration_status in [:upcoming, :closed]}
      class={[
        @class,
        @registration_status in [:upcoming, :closed] &&
          "bg-hero-grey-400 cursor-not-allowed opacity-60",
        @registration_status not in [:upcoming, :closed] &&
          "hover:shadow-lg transform hover:scale-[1.02]",
        @registration_status not in [:upcoming, :closed] && Theme.transition(:normal),
        @registration_status not in [:upcoming, :closed] && Theme.gradient(:primary)
      ]}
    >
      <%= cond do %>
        <% @registration_status == :upcoming -> %>
          {gettext("Registration Not Open Yet")}
        <% @registration_status == :closed -> %>
          {gettext("Registration Closed")}
        <% true -> %>
          {@label}
      <% end %>
    </button>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen pb-24 md:pb-6", Theme.bg(:muted)]}>
      <%!-- Hero Section --%>
      <div class={["relative", Theme.gradient(:hero)]}>
        <div class="absolute inset-0 bg-black/20"></div>

        <%!-- Navigation Bar --%>
        <div class="relative max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 pt-4">
          <div class="flex items-center justify-between">
            <.back_button phx-click="back_to_programs" />
            <button
              phx-click="toggle_favorite"
              class={[
                "p-2 bg-white/80 backdrop-blur-sm hover:bg-white",
                Theme.transition(:normal),
                Theme.rounded(:full)
              ]}
            >
              <svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 24 24">
                <path d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
              </svg>
            </button>
          </div>
        </div>

        <%!-- Program Icon --%>
        <div class="relative flex justify-center py-6">
          <div class={[
            "w-20 h-20 bg-white/20 backdrop-blur-sm flex items-center justify-center",
            Theme.rounded(:full)
          ]}>
            <svg class="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d={@program.icon_path}
              >
              </path>
            </svg>
          </div>
        </div>

        <%!-- Program Title & Info (Centered in Hero) --%>
        <div class="relative pb-12 px-4">
          <div class="max-w-4xl mx-auto text-center text-white">
            <h1 class={[Theme.typography(:page_title), "mb-3"]}>
              {@program.title}
            </h1>
            <div class="flex flex-wrap items-center justify-center gap-4 text-sm text-white/90 mb-4">
              <%= if schedule = ProgramPresenter.format_schedule(@program) do %>
                <span class="flex items-center">
                  <.icon name="hero-clock" class="w-4 h-4 mr-1" />
                  <%= if schedule.days do %>
                    {schedule.days}
                    <%= if schedule.times do %>
                      <span class="mx-1">&middot;</span>
                      {schedule.times}
                    <% end %>
                  <% else %>
                    {schedule.times}
                  <% end %>
                </span>
              <% else %>
                <span class="flex items-center">
                  <.icon name="hero-clock" class="w-4 h-4 mr-1" />
                  {gettext("Schedule TBD")}
                </span>
              <% end %>
              <span class="flex items-center">
                <.icon name="hero-user-group" class="w-4 h-4 mr-1" />
                {gettext("Ages %{range}", range: @program.age_range)}
              </span>
              <span class="flex items-center">
                <.icon name="hero-map-pin" class="w-4 h-4 mr-1" /> Berlin
              </span>
            </div>
            <%!-- Badges --%>
            <div class="flex flex-wrap justify-center gap-2">
              <span class={[
                "px-3 py-1 text-xs font-medium bg-white/90 backdrop-blur-sm text-green-700",
                Theme.rounded(:full)
              ]}>
                {gettext("✓ No hidden fees")}
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- Registration Status Banner --%>
      <div
        :if={@registration_status in [:upcoming, :closed]}
        class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 -mt-3 relative z-10 mb-3"
      >
        <div class={[
          "p-4 shadow-sm border flex items-center gap-3",
          Theme.rounded(:xl),
          if(@registration_status == :upcoming,
            do: "bg-blue-50 border-blue-200 text-blue-800",
            else: "bg-hero-grey-100 border-hero-grey-300 text-hero-grey-700"
          )
        ]}>
          <span class="text-xl">
            <%= if @registration_status == :upcoming do %>
              📅
            <% else %>
              🔒
            <% end %>
          </span>
          <p class="text-sm font-medium">
            {registration_status_title(@registration_status, @program)}
          </p>
        </div>
      </div>

      <%!-- Pricing Card (Overlapping Hero) --%>
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 -mt-6 relative z-10">
        <div class={[
          Theme.bg(:surface),
          Theme.rounded(:xl),
          "p-6 shadow-lg border",
          Theme.border_color(:light)
        ]}>
          <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div>
              <p class={[Theme.typography(:page_title), Theme.text_color(:heading)]}>
                {ProgramCatalog.format_total_price(@program.price)}
              </p>
              <p class={["text-sm", Theme.text_color(:muted)]}>
                {gettext("Total: Sept 1 - Oct 26")}
              </p>
              <p class={["text-xs mt-1", Theme.text_color(:subtle)]}>
                {gettext("%{price}/week • 4 weeks",
                  price: ProgramCatalog.format_price(@program.price)
                )}
              </p>
              <p class={["text-xs mt-1", Theme.text_color(:secondary)]}>
                {gettext("with %{name}", name: @instructor.name)}
              </p>
            </div>
            <div class="flex flex-col sm:flex-row gap-3">
              <.enroll_button
                id="book-now-button"
                class={"text-white py-3 px-6 #{Theme.typography(:card_title)} #{Theme.rounded(:lg)}"}
                registration_status={@registration_status}
                label={gettext("Book Now")}
              />
              <button
                phx-click="save_for_later"
                class={[
                  "py-3 px-6 border-2",
                  Theme.border_color(:medium),
                  Theme.text_color(:body),
                  Theme.rounded(:lg),
                  "hover:bg-hero-grey-50",
                  Theme.transition(:normal)
                ]}
              >
                {gettext("Save for Later")}
              </button>
            </div>
          </div>
          <p class={[
            "text-center text-sm mt-4 pt-4 border-t",
            Theme.border_color(:light),
            Theme.text_color(:secondary)
          ]}>
            <.icon name="hero-check-circle" class="w-4 h-4 inline mr-1 text-green-500" />
            {gettext("Free cancellation up to 48 hours before start date")}
          </p>
        </div>
      </div>

      <%!-- Main Content Sections --%>
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        <%!-- About This Program Section --%>
        <section>
          <div class={[
            Theme.bg(:surface),
            Theme.rounded(:xl),
            "shadow-sm border overflow-hidden",
            Theme.border_color(:light)
          ]}>
            <div class={["p-4 border-b", Theme.border_color(:light)]}>
              <h3 class={["font-semibold flex items-center gap-2", Theme.text_color(:heading)]}>
                <.icon name="hero-information-circle" class="w-5 h-5 text-hero-blue-500" />
                {gettext("About This Program")}
              </h3>
            </div>
            <div class="p-6">
              <p class={["leading-relaxed mb-6", Theme.text_color(:secondary)]}>
                {@program.description}
              </p>

              <div class="space-y-3">
                <h4 class={["font-semibold", Theme.text_color(:heading)]}>
                  {gettext("What's Included:")}
                </h4>
                <ul class={["space-y-2 text-sm", Theme.text_color(:secondary)]}>
                  <li :for={item <- @program.included_items} class="flex items-start">
                    <.icon name="hero-check" class="w-5 h-5 text-green-500 mr-2 flex-shrink-0" />
                    <span>{item}</span>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </section>

        <%!-- Participant Requirements Section --%>
        <.restriction_info :if={@participant_policy} policy={@participant_policy} />

        <%!-- Meet the Team / Instructor Section --%>
        <section>
          <div class={[
            Theme.bg(:surface),
            Theme.rounded(:xl),
            "shadow-sm border overflow-hidden",
            Theme.border_color(:light)
          ]}>
            <div class={["p-4 border-b", Theme.border_color(:light)]}>
              <h3 class={["font-semibold flex items-center gap-2", Theme.text_color(:heading)]}>
                <.icon name="hero-user" class="w-5 h-5 text-hero-blue-500" />
                <%= if length(@team_members) > 1 do %>
                  {gettext("Meet the Team")}
                <% else %>
                  {gettext("Meet Your Instructor")}
                <% end %>
              </h3>
            </div>
            <div class="p-6">
              <%= if @team_members != [] do %>
                <div class="space-y-6">
                  <div :for={member <- @team_members} class="flex items-start space-x-4">
                    <img
                      :if={member.headshot_url}
                      src={member.headshot_url}
                      alt={member.full_name}
                      class={[
                        "w-16 h-16 object-cover flex-shrink-0",
                        Theme.rounded(:full)
                      ]}
                    />
                    <div
                      :if={!member.headshot_url}
                      class={[
                        "w-16 h-16 flex items-center justify-center text-white text-xl font-bold flex-shrink-0",
                        Theme.rounded(:full),
                        Theme.gradient(:primary)
                      ]}
                    >
                      {member.initials}
                    </div>
                    <div class="flex-1">
                      <h4 class={["font-semibold", Theme.text_color(:heading)]}>
                        {member.full_name}
                      </h4>
                      <p :if={member.role} class={["text-sm mb-2", Theme.text_color(:muted)]}>
                        {member.role}
                      </p>
                      <p
                        :if={member.bio}
                        class={["text-sm leading-relaxed mb-3", Theme.text_color(:secondary)]}
                      >
                        {member.bio}
                      </p>
                      <div :if={member.tags != []} class="flex flex-wrap gap-1.5 mb-2">
                        <span
                          :for={tag <- member.tags}
                          class={[
                            "px-2 py-0.5 text-xs font-medium bg-hero-cyan-100 text-hero-cyan",
                            Theme.rounded(:full)
                          ]}
                        >
                          {tag}
                        </span>
                      </div>
                      <div :if={member.qualifications != []} class="flex flex-wrap gap-1.5">
                        <span
                          :for={qual <- member.qualifications}
                          class={[
                            "px-2 py-0.5 text-xs font-medium border border-hero-grey-300 text-hero-grey-600",
                            Theme.rounded(:md)
                          ]}
                        >
                          {qual}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              <% else %>
                <%!-- Fallback to sample instructor when no staff members exist --%>
                <div class="flex items-start space-x-4">
                  <.user_avatar size="lg" />
                  <div class="flex-1">
                    <h4 class={["font-semibold", Theme.text_color(:heading)]}>
                      {@instructor.name}
                    </h4>
                    <p class={["text-sm mb-2", Theme.text_color(:muted)]}>
                      {@instructor.credentials}
                    </p>
                    <p class={["text-sm leading-relaxed mb-3", Theme.text_color(:secondary)]}>
                      {@instructor.bio}
                    </p>
                    <div class="flex items-center">
                      <.star_rating
                        rating={@instructor.rating}
                        size={:medium}
                        show_count
                        count={@instructor.review_count}
                      />
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </section>

        <%!-- What Other Parents Say Section --%>
        <section>
          <div class={[
            Theme.bg(:surface),
            Theme.rounded(:xl),
            "shadow-sm border overflow-hidden",
            Theme.border_color(:light)
          ]}>
            <div class={["p-4 border-b", Theme.border_color(:light)]}>
              <h3 class={["font-semibold flex items-center gap-2", Theme.text_color(:heading)]}>
                <.icon name="hero-star" class="w-5 h-5 text-hero-yellow-400" />
                {gettext("What Other Parents Say")}
              </h3>
            </div>
            <div class="p-6">
              <div class="space-y-4">
                <.review_card
                  :for={review <- @reviews}
                  parent_name={review.parent_name}
                  child_name={review.child_name}
                  child_age={review.child_age}
                  rating={5.0}
                  comment={review.comment}
                  verified={true}
                />
              </div>

              <div class="text-center mt-6 pt-4 border-t border-hero-grey-100">
                <button class={[
                  Theme.text_color(:primary),
                  "text-sm font-medium hover:opacity-80"
                ]}>
                  {gettext("View all %{count} reviews →", count: @instructor.review_count)}
                </button>
              </div>
            </div>
          </div>
        </section>

        <%!-- Bottom CTA (Hidden on Mobile - Mobile has sticky footer) --%>
        <div class="hidden md:block mt-8">
          <.enroll_button
            id="enroll-bottom-cta"
            class={"w-full text-white py-4 px-6 #{Theme.typography(:card_title)} #{Theme.rounded(:lg)}"}
            registration_status={@registration_status}
            label={
              gettext("Enroll Now - %{price}",
                price: ProgramCatalog.format_total_price(@program.price)
              )
            }
          />
        </div>
      </div>

      <%!-- Mobile Sticky CTA Footer --%>
      <div class={[
        "fixed bottom-0 left-0 right-0 md:hidden border-t p-4 z-50",
        Theme.bg(:surface),
        Theme.border_color(:light)
      ]}>
        <div class="flex items-center justify-between gap-4 max-w-4xl mx-auto">
          <div>
            <p class={["font-semibold", Theme.text_color(:heading)]}>
              {ProgramCatalog.format_total_price(@program.price)}
            </p>
            <p class={["text-xs", Theme.text_color(:muted)]}>
              {gettext("%{price}/week", price: ProgramCatalog.format_price(@program.price))}
            </p>
          </div>
          <.enroll_button
            id="enroll-mobile-cta"
            class={"flex-1 text-white py-3 px-4 max-w-xs #{Theme.typography(:card_title)} #{Theme.rounded(:lg)}"}
            registration_status={@registration_status}
            label={gettext("Book Now")}
          />
        </div>
      </div>
    </div>
    """
  end
end
