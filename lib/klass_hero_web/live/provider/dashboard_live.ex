defmodule KlassHeroWeb.Provider.DashboardLive do
  @moduledoc """
  Provider dashboard LiveView with tab-based navigation.

  Sections:
  - Overview: Stats, business profile, verification badges
  - Team & Profiles: Team member management
  - My Programs: Program inventory and management
  - Edit: Profile editing with logo/verification doc uploads
  """
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.ProviderComponents

  alias KlassHero.ProgramCatalog
  alias KlassHero.Provider
  alias KlassHero.Shared.Storage
  alias KlassHeroWeb.Presenters.ProgramPresenter
  alias KlassHeroWeb.Presenters.ProviderPresenter
  alias KlassHeroWeb.Presenters.StaffMemberPresenter
  alias KlassHeroWeb.Provider.MockData
  alias KlassHeroWeb.Theme

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.current_scope.provider do
      nil ->
        Logger.warning("Provider dashboard accessed without provider profile",
          user_id: socket.assigns.current_scope.user.id
        )

        {:ok, redirect(socket, to: ~p"/")}

      provider_profile ->
        business = ProviderPresenter.to_business_view(provider_profile)

        # Trigger: to_business_view defaults verification_status to :not_started
        # Why: full docs-based derivation happens in handle_params(:overview),
        #      but other tabs need a baseline so the "New Program" button gating works
        # Outcome: verified providers get :verified immediately; detail refinement on overview tab
        business =
          if provider_profile.verified do
            %{business | verification_status: :verified}
          else
            business
          end

        # Load real programs for this provider
        domain_programs = ProgramCatalog.list_programs_for_provider(provider_profile.id)
        programs = Enum.map(domain_programs, &ProgramPresenter.to_table_view/1)

        # Update business with actual program count
        business = %{business | program_slots_used: length(programs)}

        # Mock data for stats until features are implemented
        stats = MockData.stats()

        # Load real staff members
        {:ok, staff_members} = Provider.list_staff_members(provider_profile.id)
        staff_views = StaffMemberPresenter.to_card_view_list(staff_members)

        # Build staff filter options from real data
        staff_options =
          [%{value: "all", label: gettext("All Staff")}] ++
            Enum.map(staff_views, &%{value: &1.id, label: &1.full_name})

        # Trigger: uploads registered unconditionally in mount
        # Why: allow_upload must happen once; registering in handle_params
        #      would cause double-registration errors when patching between actions
        # Outcome: upload channels are inert on non-edit tabs (no UI renders them)
        socket =
          socket
          |> assign(page_title: gettext("Provider Dashboard"))
          |> assign(business: business)
          |> assign(stats: stats)
          |> stream(:team_members, staff_views)
          |> assign(staff_count: length(staff_views))
          |> stream(:programs, programs)
          |> assign(programs_count: length(programs))
          |> assign(staff_options: staff_options)
          |> assign(search_query: "")
          |> assign(selected_staff: "all")
          |> assign(show_staff_form: false, editing_staff_id: nil)
          |> assign(staff_form: to_form(Provider.new_staff_member_changeset()))
          |> assign(show_program_form: false)
          |> assign(program_form: to_form(ProgramCatalog.new_program_changeset()))
          |> assign(instructor_options: build_instructor_options(provider_profile.id))
          |> allow_upload(:logo,
            accept: ~w(.jpg .jpeg .png .webp),
            max_entries: 1,
            max_file_size: 2_000_000
          )
          |> allow_upload(:verification_doc,
            accept: ~w(.pdf .jpg .jpeg .png),
            max_entries: 1,
            max_file_size: 10_000_000
          )
          |> allow_upload(:headshot,
            accept: ~w(.jpg .jpeg .png .webp),
            max_entries: 1,
            max_file_size: 1_000_000
          )
          |> allow_upload(:program_cover,
            accept: ~w(.jpg .jpeg .png .webp),
            max_entries: 1,
            max_file_size: 2_000_000
          )

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{live_action: :edit}} = socket) do
    provider = socket.assigns.current_scope.provider

    changeset = Provider.change_provider_profile(provider)

    docs =
      case Provider.get_provider_verification_documents(provider.id) do
        {:ok, docs} -> docs
        {:error, _reason} -> []
      end

    socket =
      socket
      |> assign(page_title: gettext("Edit Profile"))
      |> assign(form: to_form(changeset))
      |> assign(doc_type: "business_registration")
      |> stream(:verification_docs, docs, reset: true, dom_id: &"vdoc-#{&1.id}")

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{live_action: :overview}} = socket) do
    provider = socket.assigns.current_scope.provider

    # Trigger: overview tab needs verification status derived from documents
    # Why: provider.verified alone is boolean; documents give granular status
    # Outcome: business map gets :verification_status (:verified/:pending/:rejected/:not_started)
    docs =
      case Provider.get_provider_verification_documents(provider.id) do
        {:ok, docs} -> docs
        {:error, _reason} -> []
      end

    verification_status =
      ProviderPresenter.verification_status_from_docs(provider.verified, docs)

    business = %{socket.assigns.business | verification_status: verification_status}

    {:noreply, assign(socket, business: business)}
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{live_action: :team}} = socket) do
    provider = socket.assigns.current_scope.provider

    {:ok, staff_members} = Provider.list_staff_members(provider.id)
    staff_views = StaffMemberPresenter.to_card_view_list(staff_members)

    {:noreply,
     socket
     |> stream(:team_members, staff_views, reset: true)
     |> assign(staff_count: length(staff_members))}
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{live_action: :programs}} = socket) do
    {:noreply,
     socket
     |> refresh_staff_options()
     |> reset_programs_stream()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # ============================================================================
  # Staff Member CRUD Events
  # ============================================================================

  @impl true
  def handle_event("add_member", _params, socket) do
    {:noreply,
     socket
     |> assign(show_staff_form: true, editing_staff_id: nil)
     |> assign(staff_form: to_form(Provider.new_staff_member_changeset()))}
  end

  @impl true
  def handle_event("edit_member", %{"id" => staff_id}, socket) do
    case Provider.get_staff_member(staff_id) do
      {:ok, staff} ->
        changeset = Provider.change_staff_member(staff)

        {:noreply,
         socket
         |> assign(show_staff_form: true, editing_staff_id: staff_id)
         |> assign(staff_form: to_form(changeset))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, gettext("Staff member not found."))}
    end
  end

  @impl true
  def handle_event("close_staff_form", _params, socket) do
    {:noreply, assign(socket, show_staff_form: false)}
  end

  @impl true
  def handle_event("validate_staff", %{"staff_member_schema" => params}, socket) do
    changeset =
      case socket.assigns.editing_staff_id do
        nil ->
          Provider.new_staff_member_changeset(params)

        staff_id ->
          {:ok, staff} = Provider.get_staff_member(staff_id)
          Provider.change_staff_member(staff, params)
      end

    {:noreply, assign(socket, staff_form: to_form(Map.put(changeset, :action, :validate)))}
  end

  @impl true
  def handle_event("save_staff", %{"staff_member_schema" => params}, socket) do
    provider = socket.assigns.current_scope.provider

    # Trigger: headshot upload may be present or absent
    # Why: staff member can be saved without a headshot
    # Outcome: include headshot_url in attrs if upload succeeded
    headshot_result = upload_headshot(socket, provider.id)

    case socket.assigns.editing_staff_id do
      nil ->
        attrs =
          params
          |> atomize_staff_params()
          |> Map.put(:provider_id, provider.id)
          |> maybe_add_headshot(headshot_result)

        case Provider.create_staff_member(attrs) do
          {:ok, staff} ->
            view = StaffMemberPresenter.to_card_view(staff)

            {:noreply,
             socket
             |> stream_insert(:team_members, view)
             |> assign(
               show_staff_form: false,
               staff_count: socket.assigns.staff_count + 1
             )
             |> clear_flash(:error)
             |> put_flash(:info, gettext("Team member added."))}

          {:error, {:validation_error, _errors}} ->
            changeset =
              Provider.new_staff_member_changeset(params)
              |> Map.put(:action, :validate)

            {:noreply,
             socket
             |> assign(staff_form: to_form(changeset))
             |> put_flash(:error, gettext("Please fix the errors below."))}

          {:error, changeset} ->
            {:noreply, assign(socket, staff_form: to_form(changeset))}
        end

      staff_id ->
        attrs =
          params
          |> atomize_staff_params()
          |> maybe_add_headshot(headshot_result)

        case Provider.update_staff_member(staff_id, attrs) do
          {:ok, staff} ->
            view = StaffMemberPresenter.to_card_view(staff)

            {:noreply,
             socket
             |> stream_insert(:team_members, view)
             |> assign(show_staff_form: false)
             |> clear_flash(:error)
             |> put_flash(:info, gettext("Team member updated."))}

          {:error, {:validation_error, _errors}} ->
            {:ok, staff} = Provider.get_staff_member(staff_id)

            changeset =
              Provider.change_staff_member(staff, params)
              |> Map.put(:action, :validate)

            {:noreply,
             socket
             |> assign(staff_form: to_form(changeset))
             |> put_flash(:error, gettext("Please fix the errors below."))}

          {:error, changeset} ->
            {:noreply, assign(socket, staff_form: to_form(changeset))}
        end
    end
  end

  @impl true
  def handle_event("delete_member", %{"id" => staff_id}, socket) do
    case Provider.delete_staff_member(staff_id) do
      :ok ->
        {:noreply,
         socket
         |> stream_delete_by_dom_id(:team_members, "team_members-#{staff_id}")
         |> assign(staff_count: max(0, socket.assigns.staff_count - 1))
         |> clear_flash(:error)
         |> put_flash(:info, gettext("Team member removed."))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, gettext("Staff member not found."))}
    end
  end

  # ============================================================================
  # Edit Profile Events
  # ============================================================================

  @impl true
  def handle_event("validate_profile", %{"provider_profile_schema" => params}, socket) do
    provider = socket.assigns.current_scope.provider
    changeset = Provider.change_provider_profile(provider, params)

    {:noreply, assign(socket, form: to_form(Map.put(changeset, :action, :validate)))}
  end

  @impl true
  def handle_event("save_profile", %{"provider_profile_schema" => params}, socket) do
    provider = socket.assigns.current_scope.provider

    # Trigger: logo upload may succeed, be absent, or fail
    # Why: provider can save without a new logo, but upload failures must not be silently ignored
    # Outcome: :upload_error aborts save; :no_upload proceeds without logo; {:ok, url} includes logo
    case upload_logo(socket, provider.id) do
      :upload_error ->
        {:noreply, put_flash(socket, :error, gettext("Logo upload failed. Please try again."))}

      logo_result ->
        attrs = %{description: params["description"]}

        attrs =
          case logo_result do
            {:ok, url} -> Map.put(attrs, :logo_url, url)
            :no_upload -> attrs
          end

        case Provider.update_provider_profile(provider.id, attrs) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Profile updated successfully."))
             |> push_navigate(to: ~p"/provider/dashboard")}

          {:error, {:validation_error, _errors}} ->
            {:noreply, put_flash(socket, :error, gettext("Please fix the errors below."))}

          {:error, :not_found} ->
            {:noreply,
             socket
             |> put_flash(:error, gettext("Provider profile not found."))
             |> push_navigate(to: ~p"/")}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
    end
  end

  @impl true
  def handle_event("upload_verification_doc", _params, socket) do
    provider = socket.assigns.current_scope.provider
    doc_type = socket.assigns.doc_type

    results =
      consume_uploaded_entries(socket, :verification_doc, fn %{path: path}, entry ->
        file_binary = File.read!(path)

        case Provider.submit_verification_document(%{
               provider_profile_id: provider.id,
               document_type: doc_type,
               file_binary: file_binary,
               original_filename: entry.client_name,
               content_type: entry.client_type
             }) do
          {:ok, doc} -> {:ok, doc}
          {:error, reason} -> {:postpone, reason}
        end
      end)

    case results do
      [{:ok, doc}] ->
        {:noreply,
         socket
         |> stream_insert(:verification_docs, doc, dom_id: &"vdoc-#{&1.id}")
         |> put_flash(:info, gettext("Document uploaded successfully."))}

      other ->
        Logger.error("Verification document upload failed",
          provider_id: provider.id,
          doc_type: doc_type,
          errors: inspect(other)
        )

        {:noreply, put_flash(socket, :error, gettext("Failed to upload document."))}
    end
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_doc_type", %{"doc_type" => doc_type}, socket) do
    {:noreply, assign(socket, doc_type: doc_type)}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref, "upload" => upload_name}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(upload_name), ref)}
  end

  # ============================================================================
  # Program Creation Events
  # ============================================================================

  @impl true
  def handle_event("add_program", _params, socket) do
    {:noreply,
     socket
     |> assign(show_program_form: true)
     |> assign(program_form: to_form(ProgramCatalog.new_program_changeset()))
     |> assign(
       instructor_options: build_instructor_options(socket.assigns.current_scope.provider.id)
     )}
  end

  @impl true
  def handle_event("close_program_form", _params, socket) do
    {:noreply, assign(socket, show_program_form: false)}
  end

  @impl true
  def handle_event("validate_program", %{"program_schema" => params}, socket) do
    changeset =
      ProgramCatalog.new_program_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, program_form: to_form(changeset))}
  end

  @impl true
  def handle_event("save_program", %{"program_schema" => params}, socket) do
    provider = socket.assigns.current_scope.provider

    # Trigger: cover image upload may succeed, be absent, or fail
    # Why: upload failures must not be silently ignored (mirrors save_profile pattern)
    # Outcome: :upload_error aborts save; :no_upload proceeds without cover; {:ok, url} includes it
    case upload_program_cover(socket, provider.id) do
      :upload_error ->
        {:noreply,
         put_flash(socket, :error, gettext("Cover image upload failed. Please try again."))}

      cover_result ->
        attrs =
          %{
            provider_id: provider.id,
            title: params["title"],
            description: params["description"],
            category: params["category"],
            price: parse_decimal(params["price"]),
            location: presence(params["location"])
          }
          |> maybe_add_cover_image(cover_result)

        with {:ok, attrs} <- maybe_add_instructor(attrs, params["instructor_id"], socket),
             {:ok, program} <- ProgramCatalog.create_program(attrs) do
          view = ProgramPresenter.to_table_view(program)

          {:noreply,
           socket
           |> stream_insert(:programs, view)
           |> assign(
             show_program_form: false,
             programs_count: socket.assigns.programs_count + 1
           )
           |> clear_flash(:error)
           |> put_flash(:info, gettext("Program created successfully."))}
        else
          {:error, :instructor_not_found} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Selected instructor could not be found. Please try again.")
             )}

          # Trigger: domain validation returns a list of error strings
          # Why: Program.create/1 validates invariants before persistence
          # Outcome: show errors as flash message, form stays open
          {:error, errors} when is_list(errors) ->
            {:noreply, put_flash(socket, :error, Enum.join(errors, ", "))}

          # Trigger: Ecto changeset validation failed at persistence layer
          # Why: defense-in-depth — schema catches anything domain missed
          # Outcome: show inline field errors via changeset-backed form
          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(program_form: to_form(Map.put(changeset, :action, :validate)))
             |> put_flash(:error, gettext("Please fix the errors below."))}
        end
    end
  end

  # ============================================================================
  # Dashboard Tab Events
  # ============================================================================

  @impl true
  def handle_event("search_programs", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(search_query: query)
     |> reset_programs_stream()}
  end

  @impl true
  def handle_event("filter_by_staff", %{"staff_filter" => staff_id}, socket) do
    {:noreply,
     socket
     |> assign(selected_staff: staff_id)
     |> reset_programs_stream()}
  end

  # ============================================================================
  # Render
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", Theme.bg(:muted)]}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <%= case @live_action do %>
          <% :edit -> %>
            <.edit_profile_section
              form={@form}
              uploads={@uploads}
              business={@business}
              verification_docs={@streams.verification_docs}
              doc_type={@doc_type}
            />
          <% _ -> %>
            <.provider_dashboard_header business={@business} />
            <.provider_nav_tabs live_action={@live_action} />

            <%= case @live_action do %>
              <% :overview -> %>
                <.overview_section stats={@stats} business={@business} />
              <% :team -> %>
                <.team_section
                  team_members={@streams.team_members}
                  show_staff_form={@show_staff_form}
                  editing_staff_id={@editing_staff_id}
                  staff_form={@staff_form}
                  uploads={@uploads}
                />
              <% :programs -> %>
                <.programs_section
                  programs={@streams.programs}
                  staff_options={@staff_options}
                  search_query={@search_query}
                  selected_staff={@selected_staff}
                  show_program_form={@show_program_form}
                  program_form={@program_form}
                  uploads={@uploads}
                  instructor_options={@instructor_options}
                />
            <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Edit Profile Template
  # ============================================================================

  defp edit_profile_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-4 mb-6">
        <.link
          navigate={~p"/provider/dashboard"}
          class="flex items-center gap-1 text-hero-grey-500 hover:text-hero-charcoal transition-colors"
        >
          <.icon name="hero-arrow-left-mini" class="w-5 h-5" />
          {gettext("Back to Dashboard")}
        </.link>
      </div>

      <h1 class="text-2xl font-bold text-hero-charcoal">{gettext("Edit Profile")}</h1>

      <%!-- Profile Form --%>
      <div class={["bg-white p-6 shadow-sm border border-hero-grey-200", Theme.rounded(:xl)]}>
        <h2 class="text-lg font-semibold text-hero-charcoal mb-4">
          {gettext("Business Information")}
        </h2>

        <.form
          for={@form}
          id="profile-form"
          phx-change="validate_profile"
          phx-submit="save_profile"
          class="space-y-6"
        >
          <.input
            field={@form[:description]}
            type="textarea"
            label={gettext("Business Description")}
            placeholder={gettext("Tell parents about your organization...")}
            rows="4"
          />

          <%!-- Logo Upload --%>
          <div>
            <label class="block text-sm font-semibold text-hero-charcoal mb-2">
              {gettext("Business Logo")}
            </label>

            <div
              id="logo-upload"
              class={[
                "border-2 border-dashed border-hero-grey-300 p-6 text-center",
                Theme.rounded(:lg)
              ]}
              phx-drop-target={@uploads.logo.ref}
            >
              <%!-- Current logo preview --%>
              <div :if={@business.initials} class="mb-4">
                <div class={[
                  "w-16 h-16 mx-auto flex items-center justify-center text-white text-xl font-bold",
                  Theme.rounded(:full),
                  Theme.gradient(:primary)
                ]}>
                  {@business.initials}
                </div>
              </div>

              <%!-- Upload entries preview --%>
              <div :for={entry <- @uploads.logo.entries} class="mb-4">
                <.live_img_preview entry={entry} class="w-16 h-16 mx-auto rounded-full object-cover" />
                <p class="text-sm text-hero-grey-500 mt-1">{entry.client_name}</p>
                <button
                  type="button"
                  phx-click="cancel_upload"
                  phx-value-ref={entry.ref}
                  phx-value-upload="logo"
                  class="text-xs text-red-500 hover:text-red-700 mt-1"
                >
                  {gettext("Remove")}
                </button>
                <div
                  :for={err <- upload_errors(@uploads.logo, entry)}
                  class="text-xs text-red-500 mt-1"
                >
                  {upload_error_to_string(err)}
                </div>
              </div>

              <.live_file_input upload={@uploads.logo} class="hidden" />
              <label
                for={@uploads.logo.ref}
                class={[
                  "inline-flex items-center gap-2 px-4 py-2 border border-hero-grey-300",
                  "bg-white hover:bg-hero-grey-50 text-hero-charcoal text-sm font-medium cursor-pointer",
                  Theme.rounded(:lg),
                  Theme.transition(:normal)
                ]}
              >
                <.icon name="hero-photo-mini" class="w-4 h-4" />
                {gettext("Choose Logo")}
              </label>
              <p class="text-xs text-hero-grey-400 mt-2">
                {gettext("JPG, PNG or WebP. Max 2MB.")}
              </p>
            </div>
          </div>

          <div class="flex justify-end">
            <button
              type="submit"
              id="save-profile-btn"
              class={[
                "flex items-center gap-2 px-6 py-2.5 bg-hero-yellow hover:bg-hero-yellow-dark",
                "text-hero-charcoal font-semibold",
                Theme.rounded(:lg),
                Theme.transition(:normal)
              ]}
            >
              <.icon name="hero-check-mini" class="w-5 h-5" />
              {gettext("Save Changes")}
            </button>
          </div>
        </.form>
      </div>

      <.verification_documents_panel
        verification_docs={@verification_docs}
        uploads={@uploads}
        doc_type={@doc_type}
      />
    </div>
    """
  end

  # ============================================================================
  # Dashboard Tab Templates
  # ============================================================================

  defp overview_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <.provider_stat_card
          label={gettext("Total Revenue")}
          value={format_currency(@stats.total_revenue)}
          icon="hero-currency-euro-mini"
          icon_bg="bg-green-100"
          icon_color="text-green-600"
        />
        <.provider_stat_card
          label={gettext("Active Bookings")}
          value={to_string(@stats.active_bookings)}
          icon="hero-calendar-days-mini"
          icon_bg="bg-hero-cyan-100"
          icon_color="text-hero-cyan"
        />
        <.provider_stat_card
          label={gettext("Profile Views")}
          value={format_number(@stats.profile_views)}
          icon="hero-eye-mini"
          icon_bg="bg-purple-100"
          icon_color="text-purple-600"
        />
        <.provider_stat_card
          label={gettext("Avg Rating")}
          value={to_string(@stats.average_rating)}
          icon="hero-star-mini"
          icon_bg="bg-hero-yellow-100"
          icon_color="text-hero-yellow"
        />
      </div>

      <.business_profile_card business={@business} />
    </div>
    """
  end

  defp team_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 class="text-xl font-semibold text-hero-charcoal">
            {gettext("Team & Provider Profiles")}
          </h2>
          <p class="text-sm text-hero-grey-500">
            {gettext(
              "Create profiles for your staff. These will be visible to parents when assigned to programs."
            )}
          </p>
        </div>
        <button
          type="button"
          id="add-member-btn"
          phx-click="add_member"
          class={[
            "flex items-center gap-2 px-4 py-2 bg-hero-yellow hover:bg-hero-yellow-dark",
            "text-hero-charcoal font-semibold",
            Theme.rounded(:lg),
            Theme.transition(:normal)
          ]}
        >
          <.icon name="hero-user-plus-mini" class="w-5 h-5" />
          {gettext("Add Team Member")}
        </button>
      </div>

      <%= if @show_staff_form do %>
        <.staff_member_form
          form={@staff_form}
          editing={@editing_staff_id != nil}
          uploads={@uploads}
        />
      <% end %>

      <div
        id="team-members"
        phx-update="stream"
        class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
      >
        <div id="team-members-empty" class="hidden only:block col-span-full">
          <.empty_state
            icon="hero-user-group"
            title={gettext("No team members yet")}
            description={gettext("Add your first staff member to get started!")}
          />
        </div>
        <div :for={{id, member} <- @team_members} id={id}>
          <.team_member_card member={member} />
        </div>
      </div>
    </div>
    """
  end

  attr :programs, :any, required: true
  attr :staff_options, :list, required: true
  attr :search_query, :string, required: true
  attr :selected_staff, :string, required: true
  attr :show_program_form, :boolean, required: true
  attr :program_form, :any, required: true
  attr :uploads, :map, required: true
  attr :instructor_options, :list, required: true

  defp programs_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @show_program_form do %>
        <.program_form
          form={@program_form}
          uploads={@uploads}
          instructor_options={@instructor_options}
        />
      <% end %>

      <.programs_table
        programs={@programs}
        staff_options={@staff_options}
        search_query={@search_query}
        selected_staff={@selected_staff}
      />
    </div>
    """
  end

  # ============================================================================
  # Upload Helpers
  # ============================================================================

  # Trigger: upload entries may be empty (user didn't pick a file)
  # Why: consume_uploaded_entries returns [] when no entries exist
  # Outcome: {:ok, url} on success, :no_upload if no file selected, :upload_error on failure
  defp consume_single_upload(socket, upload_name, storage_prefix, provider_id) do
    case consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
           file_binary = File.read!(path)
           safe_name = String.replace(entry.client_name, ~r/[^a-zA-Z0-9._-]/, "_")
           storage_path = "#{storage_prefix}/providers/#{provider_id}/#{safe_name}"

           Storage.upload(:public, storage_path, file_binary, content_type: entry.client_type)
         end) do
      [{:ok, url}] -> {:ok, url}
      [] -> :no_upload
      _other -> :upload_error
    end
  end

  defp upload_logo(socket, provider_id) do
    consume_single_upload(socket, :logo, "logos", provider_id)
  end

  defp refresh_staff_options(socket) do
    provider_id = socket.assigns.current_scope.provider.id
    {:ok, staff_members} = Provider.list_staff_members(provider_id)
    staff_views = StaffMemberPresenter.to_card_view_list(staff_members)

    staff_options =
      [%{value: "all", label: gettext("All Staff")}] ++
        Enum.map(staff_views, &%{value: &1.id, label: &1.full_name})

    assign(socket, staff_options: staff_options)
  end

  defp reset_programs_stream(socket) do
    provider_id = socket.assigns.current_scope.provider.id

    programs =
      ProgramCatalog.list_programs_for_provider(provider_id)
      |> Enum.map(&ProgramPresenter.to_table_view/1)
      |> filter_by_search(socket.assigns.search_query)
      |> filter_by_staff(socket.assigns.selected_staff)

    socket
    |> stream(:programs, programs, reset: true)
    |> assign(programs_count: length(programs))
  end

  defp filter_by_search(programs, ""), do: programs

  defp filter_by_search(programs, query) do
    query_lower = String.downcase(query)

    Enum.filter(programs, fn program ->
      String.contains?(String.downcase(program.name), query_lower)
    end)
  end

  defp filter_by_staff(programs, "all"), do: programs

  defp filter_by_staff(programs, staff_id) do
    Enum.filter(programs, fn program ->
      program.assigned_staff && to_string(program.assigned_staff.id) == staff_id
    end)
  end

  defp upload_headshot(socket, provider_id) do
    consume_single_upload(socket, :headshot, "headshots", provider_id)
  end

  defp atomize_staff_params(params) do
    # Trigger: form params arrive as string keys with "" for unfilled optional fields
    # Why: use cases and domain model expect atom keys; empty strings must become nil
    #      for optional fields; hidden checkbox input sends [""] when unchecked
    # Outcome: clean map ready for domain validation
    %{
      first_name: params["first_name"],
      last_name: params["last_name"],
      role: presence(params["role"]),
      email: presence(params["email"]),
      bio: presence(params["bio"]),
      tags: (params["tags"] || []) |> Enum.reject(&(&1 == "")),
      qualifications: parse_qualifications(params["qualifications"])
    }
  end

  defp presence(""), do: nil
  defp presence(nil), do: nil
  defp presence(value), do: value

  defp parse_decimal(nil), do: nil
  defp parse_decimal(""), do: nil
  defp parse_decimal(%Decimal{} = d), do: d
  defp parse_decimal(value) when is_binary(value), do: Decimal.new(value)

  defp parse_qualifications(nil), do: []
  defp parse_qualifications(""), do: []

  defp parse_qualifications(quals) when is_binary(quals) do
    quals
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_qualifications(quals) when is_list(quals), do: quals

  defp maybe_add_headshot(attrs, {:ok, url}), do: Map.put(attrs, :headshot_url, url)
  defp maybe_add_headshot(attrs, _), do: attrs

  defp upload_program_cover(socket, provider_id) do
    consume_single_upload(socket, :program_cover, "program_covers", provider_id)
  end

  defp maybe_add_cover_image(attrs, {:ok, url}), do: Map.put(attrs, :cover_image_url, url)
  defp maybe_add_cover_image(attrs, _), do: attrs

  # Trigger: instructor_id may be nil/"" (none selected) or a valid UUID
  # Why: instructor is optional; when selected, we resolve display data from Provider
  # Outcome: {:ok, attrs} enriched with instructor data, or {:error, :instructor_not_found}
  defp maybe_add_instructor(attrs, nil, _socket), do: {:ok, attrs}
  defp maybe_add_instructor(attrs, "", _socket), do: {:ok, attrs}

  defp maybe_add_instructor(attrs, instructor_id, socket) do
    case Provider.get_staff_member(instructor_id) do
      {:ok, staff} ->
        {:ok,
         Map.put(attrs, :instructor, %{
           id: staff.id,
           name: Provider.staff_member_full_name(staff),
           headshot_url: staff.headshot_url
         })}

      {:error, _reason} ->
        Logger.warning("Instructor not found during program creation",
          instructor_id: instructor_id,
          provider_id: socket.assigns.current_scope.provider.id
        )

        {:error, :instructor_not_found}
    end
  end

  defp build_instructor_options(provider_id) do
    case Provider.list_active_staff_members(provider_id) do
      {:ok, members} ->
        Enum.map(members, fn m ->
          {Provider.staff_member_full_name(m), m.id}
        end)

      {:error, reason} ->
        Logger.warning("Failed to load instructor options",
          provider_id: provider_id,
          reason: inspect(reason)
        )

        []
    end
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+$)/, "\\1,")
  end

  defp format_currency(amount), do: format_number(amount)
end
