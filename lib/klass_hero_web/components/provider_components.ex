defmodule KlassHeroWeb.ProviderComponents do
  @moduledoc """
  UI components specific to the provider dashboard.
  """
  use Phoenix.Component
  use Gettext, backend: KlassHeroWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: KlassHeroWeb.Endpoint,
    router: KlassHeroWeb.Router,
    statics: KlassHeroWeb.static_paths()

  import KlassHeroWeb.CoreComponents, only: [input: 1]
  import KlassHeroWeb.UIComponents

  alias KlassHero.ProgramCatalog.Domain.Services.ProgramCategories
  alias KlassHero.Provider.Domain.Models.VerificationDocument
  alias KlassHeroWeb.Presenters.ProviderPresenter
  alias KlassHeroWeb.Theme

  @doc """
  Renders a colored status badge for a verification document status.

  ## Examples

      <.doc_status_badge status={:pending} />
      <.doc_status_badge status={:approved} />
  """
  attr :status, :atom, required: true

  def doc_status_badge(assigns) do
    {bg_class, text_class, label} = doc_status_style(assigns.status)
    assigns = assign(assigns, bg_class: bg_class, text_class: text_class, label: label)

    ~H"""
    <span class={[
      "px-2.5 py-1 text-xs font-medium",
      Theme.rounded(:full),
      @bg_class,
      @text_class
    ]}>
      {@label}
    </span>
    """
  end

  defp doc_status_style(:pending), do: {"bg-yellow-100", "text-yellow-800", gettext("Pending")}
  defp doc_status_style(:approved), do: {"bg-green-100", "text-green-800", gettext("Approved")}
  defp doc_status_style(:rejected), do: {"bg-red-100", "text-red-800", gettext("Rejected")}
  defp doc_status_style(_), do: {"bg-hero-grey-100", "text-hero-grey-600", gettext("Unknown")}

  @doc """
  Renders the provider dashboard tab navigation.

  ## Examples

      <.provider_nav_tabs live_action={@live_action} />
  """
  attr :live_action, :atom, required: true

  def provider_nav_tabs(assigns) do
    ~H"""
    <nav class="border-b border-hero-grey-200 mb-6">
      <div class="flex gap-1 overflow-x-auto pb-px -mb-px">
        <.nav_tab
          patch={~p"/provider/dashboard"}
          active={@live_action == :overview}
          icon="hero-squares-2x2-mini"
        >
          {gettext("Overview")}
        </.nav_tab>
        <.nav_tab
          patch={~p"/provider/dashboard/team"}
          active={@live_action == :team}
          icon="hero-user-group-mini"
        >
          {gettext("Team & Profiles")}
        </.nav_tab>
        <.nav_tab
          patch={~p"/provider/dashboard/programs"}
          active={@live_action == :programs}
          icon="hero-queue-list-mini"
        >
          {gettext("My Programs")}
        </.nav_tab>
      </div>
    </nav>
    """
  end

  attr :patch, :string, required: true
  attr :active, :boolean, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp nav_tab(assigns) do
    ~H"""
    <.link
      patch={@patch}
      class={[
        "flex items-center gap-2 px-4 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors",
        if(@active,
          do: "border-hero-cyan text-hero-cyan",
          else:
            "border-transparent text-hero-grey-500 hover:text-hero-grey-700 hover:border-hero-grey-300"
        )
      ]}
    >
      <.icon name={@icon} class="w-5 h-5" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a stat card for the provider dashboard.

  ## Examples

      <.provider_stat_card
        label="Total Revenue"
        value="12,500"
        icon="hero-currency-euro-mini"
        icon_bg="bg-hero-cyan-100"
        icon_color="text-hero-cyan"
      />
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :icon_bg, :string, default: "bg-hero-cyan-100"
  attr :icon_color, :string, default: "text-hero-cyan"

  def provider_stat_card(assigns) do
    ~H"""
    <div class={[
      "bg-white p-4 shadow-sm border border-hero-grey-200",
      Theme.rounded(:xl)
    ]}>
      <div class="flex items-center gap-3">
        <div class={["w-10 h-10 flex items-center justify-center", Theme.rounded(:lg), @icon_bg]}>
          <.icon name={@icon} class={"w-5 h-5 #{@icon_color}"} />
        </div>
        <div>
          <p class="text-sm text-hero-grey-500">{@label}</p>
          <p class="text-2xl font-bold text-hero-charcoal">{@value}</p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the business profile card with verification badges.

  ## Examples

      <.business_profile_card business={@business} />
  """
  attr :business, :map, required: true

  def business_profile_card(assigns) do
    ~H"""
    <div class={["bg-white p-6 shadow-sm border border-hero-grey-200", Theme.rounded(:xl)]}>
      <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 mb-4">
        <div>
          <h2 class="text-xl font-semibold text-hero-charcoal mb-1">
            {gettext("Business Profile")}
          </h2>
          <p class="text-sm text-hero-grey-500">
            {gettext(
              "This is your main business identity. Verification is required to list programs."
            )}
          </p>
        </div>
        <.link
          navigate={~p"/provider/dashboard/edit"}
          class={[
            "flex items-center gap-2 px-4 py-2 border border-hero-grey-300 bg-white",
            "hover:bg-hero-grey-50 text-hero-charcoal text-sm font-medium",
            Theme.rounded(:lg),
            Theme.transition(:normal)
          ]}
        >
          <.icon name="hero-pencil-square-mini" class="w-4 h-4" />
          {gettext("Edit Profile")}
        </.link>
      </div>

      <div class="flex items-center gap-4">
        <%!-- Logo: real image or initials placeholder --%>
        <img
          :if={@business.logo_url}
          src={@business.logo_url}
          alt={@business.name}
          id="business-logo"
          class={["w-20 h-20 object-cover", Theme.rounded(:full)]}
        />
        <div
          :if={!@business.logo_url}
          id="business-logo-placeholder"
          class={[
            "w-20 h-20 flex items-center justify-center text-white text-2xl font-bold",
            Theme.rounded(:full),
            Theme.gradient(:primary)
          ]}
        >
          {@business.initials}
        </div>
        <div>
          <h3 class="text-xl font-semibold text-hero-charcoal">{@business.name}</h3>
          <p class="text-hero-grey-500 mb-2">{@business.tagline}</p>
          <div class="flex flex-wrap gap-2">
            <.verification_status_badge status={@business.verification_status} />
            <.verification_badge
              :for={badge <- @business.verification_badges}
              icon={badge_icon(badge.key)}
              label={badge.label}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :status, :atom, required: true

  defp verification_status_badge(%{status: :verified} = assigns) do
    ~H"""
    <div
      id="verification-status"
      class={[
        "flex items-center gap-1.5 px-3 py-1.5 bg-green-100 text-green-700 text-xs font-medium",
        Theme.rounded(:full)
      ]}
    >
      <.icon name="hero-check-badge-mini" class="w-4 h-4" />
      <span class="uppercase tracking-wide">{gettext("Verified")}</span>
    </div>
    """
  end

  defp verification_status_badge(%{status: :pending} = assigns) do
    ~H"""
    <div
      id="verification-status"
      class={[
        "flex items-center gap-1.5 px-3 py-1.5 bg-yellow-100 text-yellow-700 text-xs font-medium",
        Theme.rounded(:full)
      ]}
    >
      <.icon name="hero-clock-mini" class="w-4 h-4" />
      <span class="uppercase tracking-wide">{gettext("Pending Review")}</span>
    </div>
    """
  end

  defp verification_status_badge(%{status: :rejected} = assigns) do
    ~H"""
    <div
      id="verification-status"
      class={[
        "flex items-center gap-1.5 px-3 py-1.5 bg-red-100 text-red-700 text-xs font-medium",
        Theme.rounded(:full)
      ]}
    >
      <.icon name="hero-x-circle-mini" class="w-4 h-4" />
      <span class="uppercase tracking-wide">{gettext("Action Required")}</span>
    </div>
    """
  end

  defp verification_status_badge(assigns) do
    ~H"""
    <div
      id="verification-status"
      class={[
        "flex items-center gap-1.5 px-3 py-1.5 bg-hero-grey-100 text-hero-grey-500 text-xs font-medium",
        Theme.rounded(:full)
      ]}
    >
      <.icon name="hero-document-plus-mini" class="w-4 h-4" />
      <span class="uppercase tracking-wide">{gettext("Not Verified")}</span>
    </div>
    """
  end

  defp badge_icon(:business_registration), do: "hero-check-badge-mini"
  defp badge_icon(:insurance), do: "hero-shield-check-mini"
  defp badge_icon(_), do: "hero-check-mini"

  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp verification_badge(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-1.5 px-3 py-1.5 bg-hero-grey-100 text-hero-grey-700 text-xs font-medium",
      Theme.rounded(:full)
    ]}>
      <.icon name={@icon} class="w-4 h-4 text-green-600" />
      <span class="uppercase tracking-wide">{@label}</span>
    </div>
    """
  end

  @doc """
  Renders the dashboard header with business name and badges.

  ## Examples

      <.provider_dashboard_header business={@business} />
  """
  attr :business, :map, required: true

  def provider_dashboard_header(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 mb-6">
      <div>
        <h1 class="text-2xl font-bold text-hero-charcoal mb-2">
          {@business.name} {gettext("Dashboard")}
        </h1>
        <div class="flex flex-wrap items-center gap-2">
          <span class={[
            "px-3 py-1 text-xs font-semibold text-white uppercase tracking-wide",
            Theme.rounded(:full),
            "bg-green-500"
          ]}>
            {@business.plan_label}
          </span>
          <span
            :if={@business.verified}
            class={[
              "flex items-center gap-1 px-3 py-1 text-xs font-medium border border-green-500 text-green-600",
              Theme.rounded(:full)
            ]}
          >
            <.icon name="hero-check-badge-mini" class="w-4 h-4" />
            {gettext("Verified Business")}
          </span>
        </div>
      </div>

      <div class="flex items-center gap-4">
        <div class="text-right">
          <p class="text-xs text-hero-grey-500 uppercase tracking-wide">
            {gettext("Program Slots")}
          </p>
          <p class="text-lg font-semibold text-hero-charcoal">
            {@business.program_slots_used}/{if @business.program_slots_total,
              do: @business.program_slots_total,
              else: "∞"}
          </p>
        </div>
        <div class="relative group">
          <button
            type="button"
            id="new-program-btn"
            phx-click="add_program"
            disabled={@business.verification_status != :verified}
            class={[
              "flex items-center gap-2 px-4 py-2 font-semibold",
              if(@business.verification_status == :verified,
                do: "bg-hero-yellow hover:bg-hero-yellow-dark text-hero-charcoal",
                else: "bg-hero-grey-200 text-hero-grey-400 cursor-not-allowed"
              ),
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            <.icon name="hero-plus-mini" class="w-5 h-5" />
            {gettext("New Program")}
          </button>
          <%!-- Tooltip: shown only when button is disabled --%>
          <div
            :if={@business.verification_status != :verified}
            id="new-program-tooltip"
            class={[
              "absolute right-0 top-full mt-2 w-64 p-3 bg-hero-charcoal text-white text-xs",
              "opacity-0 group-hover:opacity-100 pointer-events-none z-10",
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            {gettext("Complete business verification to create programs.")}
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a team member card.

  ## Examples

      <.team_member_card member={member} />
  """
  attr :member, :map, required: true

  def team_member_card(assigns) do
    ~H"""
    <div class={["bg-white shadow-sm border border-hero-grey-200 overflow-hidden", Theme.rounded(:xl)]}>
      <div class="relative h-24 bg-gradient-to-r from-hero-grey-200 to-hero-grey-300">
        <div
          :if={@member.role}
          class={[
            "absolute top-2 right-2 px-2 py-1 bg-white/90 text-xs font-medium text-hero-charcoal",
            Theme.rounded(:md)
          ]}
        >
          {@member.role}
        </div>
        <%!-- Headshot image or initials avatar --%>
        <img
          :if={@member.headshot_url}
          src={@member.headshot_url}
          alt={@member.full_name}
          class={[
            "absolute -bottom-8 left-4 w-16 h-16 object-cover border-4 border-white",
            Theme.rounded(:full)
          ]}
        />
        <div
          :if={!@member.headshot_url}
          class={[
            "absolute -bottom-8 left-4 w-16 h-16 flex items-center justify-center",
            "text-white text-xl font-bold border-4 border-white",
            Theme.rounded(:full),
            Theme.gradient(:primary)
          ]}
        >
          {@member.initials}
        </div>
      </div>

      <div class="pt-10 px-4 pb-4">
        <h3 class="font-semibold text-hero-charcoal">{@member.full_name}</h3>
        <p :if={@member.email} class="text-sm text-hero-grey-500 mb-2">{@member.email}</p>
        <p :if={@member.bio} class="text-sm text-hero-grey-600 mb-3 line-clamp-2">{@member.bio}</p>

        <%!-- Category tags as colored pills --%>
        <div :if={@member.tags != []} class="flex flex-wrap gap-1.5 mb-3">
          <span
            :for={tag <- @member.tags}
            class={[
              "px-2 py-1 text-xs font-medium bg-hero-cyan-100 text-hero-cyan",
              Theme.rounded(:full)
            ]}
          >
            {tag}
          </span>
        </div>

        <%!-- Qualifications as badge pills --%>
        <div :if={@member.qualifications != []} class="flex flex-wrap gap-1.5 mb-3">
          <span
            :for={qual <- @member.qualifications}
            class={[
              "px-2 py-1 text-xs font-medium border border-hero-grey-300 text-hero-grey-600",
              Theme.rounded(:md)
            ]}
          >
            {qual}
          </span>
        </div>

        <div class="flex items-center gap-2">
          <button
            type="button"
            phx-click="edit_member"
            phx-value-id={@member.id}
            class={[
              "flex-1 px-4 py-2 border border-hero-grey-300 bg-white",
              "hover:bg-hero-grey-50 text-hero-charcoal text-sm font-medium",
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            {gettext("Edit")}
          </button>
          <button
            type="button"
            phx-click="delete_member"
            phx-value-id={@member.id}
            data-confirm={gettext("Are you sure you want to remove this team member?")}
            class={[
              "p-2 text-red-500 hover:bg-red-50",
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            <.icon name="hero-x-mark-mini" class="w-5 h-5" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the staff member create/edit form.

  ## Examples

      <.staff_member_form form={@staff_form} editing={false} uploads={@uploads} />
  """
  attr :form, :any, required: true
  attr :editing, :boolean, default: false
  attr :uploads, :map, required: true

  def staff_member_form(assigns) do
    categories = ProgramCategories.program_categories()
    assigns = assign(assigns, categories: categories)

    ~H"""
    <div
      id="staff-member-form"
      class={["bg-white p-6 shadow-sm border border-hero-grey-200", Theme.rounded(:xl)]}
    >
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold text-hero-charcoal">
          <%= if @editing do %>
            {gettext("Edit Team Member")}
          <% else %>
            {gettext("Add Team Member")}
          <% end %>
        </h3>
        <button
          type="button"
          phx-click="close_staff_form"
          class={[
            "p-2 text-hero-grey-400 hover:text-hero-charcoal hover:bg-hero-grey-100",
            Theme.rounded(:lg)
          ]}
        >
          <.icon name="hero-x-mark-mini" class="w-5 h-5" />
        </button>
      </div>

      <.form
        for={@form}
        id="staff-form"
        phx-change="validate_staff"
        phx-submit="save_staff"
        class="space-y-4"
      >
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <.input
            field={@form[:first_name]}
            type="text"
            label={gettext("First Name")}
            placeholder={gettext("e.g. Mike")}
          />
          <.input
            field={@form[:last_name]}
            type="text"
            label={gettext("Last Name")}
            placeholder={gettext("e.g. Johnson")}
          />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <.input
            field={@form[:role]}
            type="text"
            label={gettext("Role")}
            placeholder={gettext("e.g. Head Coach")}
          />
          <.input
            field={@form[:email]}
            type="email"
            label={gettext("Email")}
            placeholder={gettext("e.g. mike@example.com")}
          />
        </div>

        <.input
          field={@form[:bio]}
          type="textarea"
          label={gettext("Bio")}
          placeholder={gettext("Brief description of experience and specialties...")}
        />

        <%!-- Tags as checkboxes --%>
        <div>
          <label class="block text-sm font-semibold text-hero-charcoal mb-2">
            {gettext("Specialties")}
          </label>
          <div class="flex flex-wrap gap-3">
            <label :for={cat <- @categories} class="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                name="staff_member_schema[tags][]"
                value={cat}
                checked={cat in ((@form[:tags] && @form[:tags].value) || [])}
                class="rounded border-hero-grey-300 text-hero-cyan focus:ring-hero-cyan"
              />
              {cat}
            </label>
          </div>
          <%!-- Hidden input to ensure empty tags array is sent when nothing is checked --%>
          <input type="hidden" name="staff_member_schema[tags][]" value="" />
        </div>

        <%!-- Qualifications as comma-separated text --%>
        <.input
          field={@form[:qualifications]}
          type="text"
          label={gettext("Qualifications")}
          placeholder={gettext("First Aid, UEFA B License, Child Care Cert")}
          value={qualifications_to_string(@form[:qualifications] && @form[:qualifications].value)}
        />
        <p class="text-xs text-hero-grey-400 -mt-2">
          {gettext("Separate multiple qualifications with commas")}
        </p>

        <%!-- Headshot upload --%>
        <div>
          <label class="block text-sm font-semibold text-hero-charcoal mb-2">
            {gettext("Headshot Photo")}
          </label>
          <div
            id="headshot-upload"
            class={[
              "border-2 border-dashed border-hero-grey-300 p-4 text-center",
              Theme.rounded(:lg)
            ]}
            phx-drop-target={@uploads.headshot.ref}
          >
            <div :for={entry <- @uploads.headshot.entries} class="mb-3">
              <.live_img_preview
                entry={entry}
                class="w-16 h-16 mx-auto rounded-full object-cover"
              />
              <button
                type="button"
                phx-click="cancel_upload"
                phx-value-ref={entry.ref}
                phx-value-upload="headshot"
                class="text-xs text-red-500 hover:text-red-700 mt-1"
              >
                {gettext("Remove")}
              </button>
            </div>

            <.live_file_input upload={@uploads.headshot} class="hidden" />
            <label
              for={@uploads.headshot.ref}
              class={[
                "inline-flex items-center gap-2 px-4 py-2 border border-hero-grey-300",
                "bg-white hover:bg-hero-grey-50 text-hero-charcoal text-sm font-medium cursor-pointer",
                Theme.rounded(:lg)
              ]}
            >
              <.icon name="hero-photo-mini" class="w-4 h-4" />
              {gettext("Choose Photo")}
            </label>
            <p class="text-xs text-hero-grey-400 mt-2">
              {gettext("JPG, PNG or WebP. Max 1MB.")}
            </p>
          </div>
        </div>

        <div class="flex items-center gap-3 pt-2">
          <button
            type="submit"
            id="save-staff-btn"
            class={[
              "flex items-center gap-2 px-6 py-2.5 bg-hero-yellow hover:bg-hero-yellow-dark",
              "text-hero-charcoal font-semibold",
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            <.icon name="hero-check-mini" class="w-5 h-5" />
            <%= if @editing do %>
              {gettext("Save Changes")}
            <% else %>
              {gettext("Add Member")}
            <% end %>
          </button>
          <button
            type="button"
            phx-click="close_staff_form"
            class={[
              "px-4 py-2.5 border border-hero-grey-300 bg-white",
              "hover:bg-hero-grey-50 text-hero-charcoal text-sm font-medium",
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            {gettext("Cancel")}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp qualifications_to_string(nil), do: ""
  defp qualifications_to_string(quals) when is_list(quals), do: Enum.join(quals, ", ")
  defp qualifications_to_string(quals) when is_binary(quals), do: quals

  @doc """
  Renders the program create/edit form.

  ## Examples

      <.program_form form={@program_form} uploads={@uploads} instructor_options={@instructor_options} />
  """
  attr :form, :any, required: true
  attr :editing, :boolean, default: false
  attr :uploads, :map, required: true
  attr :instructor_options, :list, default: []

  def program_form(assigns) do
    ~H"""
    <div class={["bg-white p-6 shadow-sm border border-hero-grey-200", Theme.rounded(:xl)]}>
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-hero-charcoal">
          <%= if @editing do %>
            {gettext("Edit Program")}
          <% else %>
            {gettext("New Program")}
          <% end %>
        </h3>
        <button
          type="button"
          phx-click="close_program_form"
          class="text-hero-grey-400 hover:text-hero-grey-600"
        >
          <.icon name="hero-x-mark-mini" class="w-5 h-5" />
        </button>
      </div>

      <.form
        for={@form}
        id="program-form"
        phx-change="validate_program"
        phx-submit="save_program"
        class="space-y-4"
      >
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <.input
            field={@form[:title]}
            type="text"
            label={gettext("Title")}
            placeholder={gettext("e.g., Art Adventures")}
            required
          />
          <.input
            field={@form[:category]}
            type="select"
            label={gettext("Category")}
            options={category_options()}
            prompt={gettext("Choose a category")}
            required
          />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <.input
            field={@form[:price]}
            type="number"
            label={gettext("Price (EUR)")}
            placeholder="0.00"
            step="0.01"
            min="0"
            required
          />
          <.input
            field={@form[:location]}
            type="text"
            label={gettext("Location")}
            placeholder={gettext("e.g., Community Center, Main St")}
          />
        </div>

        <%!-- Schedule Section --%>
        <div class="space-y-3">
          <p class="text-sm font-semibold text-hero-charcoal">{gettext("Schedule (optional)")}</p>

          <%!-- Meeting Days Checkboxes --%>
          <fieldset id="meeting-days-fieldset">
            <legend class="text-sm text-hero-grey-600 mb-2">{gettext("Meeting Days")}</legend>
            <div class="flex flex-wrap gap-2">
              <label
                :for={day <- ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)}
                class={[
                  "inline-flex items-center gap-1.5 px-3 py-1.5 border text-sm cursor-pointer",
                  Theme.rounded(:lg),
                  Theme.transition(:normal),
                  "has-[:checked]:bg-hero-yellow has-[:checked]:border-hero-yellow-dark has-[:checked]:font-semibold",
                  "border-hero-grey-300 hover:border-hero-grey-400"
                ]}
              >
                <input
                  type="checkbox"
                  name="program_schema[meeting_days][]"
                  value={day}
                  checked={day in (Phoenix.HTML.Form.input_value(@form, :meeting_days) || [])}
                  class="sr-only"
                />
                {String.slice(day, 0, 3)}
              </label>
            </div>
            <%!-- Hidden input ensures empty array submitted when no days checked --%>
            <input type="hidden" name="program_schema[meeting_days][]" value="" />
          </fieldset>

          <%!-- Time Inputs --%>
          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:meeting_start_time]}
              type="time"
              label={gettext("Start Time")}
            />
            <.input
              field={@form[:meeting_end_time]}
              type="time"
              label={gettext("End Time")}
            />
          </div>

          <%!-- Date Inputs --%>
          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:start_date]}
              type="date"
              label={gettext("Start Date")}
            />
            <.input
              field={@form[:end_date]}
              type="date"
              label={gettext("End Date")}
            />
          </div>
        </div>

        <.input
          field={@form[:description]}
          type="textarea"
          label={gettext("Description")}
          placeholder={gettext("Describe your program...")}
          rows="3"
          required
        />

        <%!-- Cover Image Upload --%>
        <div>
          <label class="block text-sm font-semibold text-hero-charcoal mb-2">
            {gettext("Cover Image")}
          </label>
          <div
            id="program-cover-upload"
            class={[
              "border-2 border-dashed border-hero-grey-300 p-4 text-center",
              Theme.rounded(:lg)
            ]}
            phx-drop-target={@uploads.program_cover.ref}
          >
            <div :for={entry <- @uploads.program_cover.entries} class="mb-3">
              <.live_img_preview
                entry={entry}
                class="w-full max-w-xs mx-auto rounded-lg object-cover"
              />
              <p class="text-sm text-hero-grey-500 mt-1">{entry.client_name}</p>
              <button
                type="button"
                phx-click="cancel_upload"
                phx-value-ref={entry.ref}
                phx-value-upload="program_cover"
                class="text-xs text-red-500 hover:text-red-700 mt-1"
              >
                {gettext("Remove")}
              </button>
              <div
                :for={err <- upload_errors(@uploads.program_cover, entry)}
                class="text-xs text-red-500 mt-1"
              >
                {upload_error_to_string(err)}
              </div>
            </div>

            <.live_file_input upload={@uploads.program_cover} class="hidden" />
            <label
              for={@uploads.program_cover.ref}
              class={[
                "inline-flex items-center gap-2 px-4 py-2 border border-hero-grey-300",
                "bg-white hover:bg-hero-grey-50 text-hero-charcoal text-sm font-medium cursor-pointer",
                Theme.rounded(:lg),
                Theme.transition(:normal)
              ]}
            >
              <.icon name="hero-photo-mini" class="w-4 h-4" />
              {gettext("Choose Image")}
            </label>
            <p class="text-xs text-hero-grey-400 mt-2">
              {gettext("JPG, PNG or WebP. Max 2MB.")}
            </p>
          </div>
        </div>

        <%!-- Assign Instructor --%>
        <.input
          field={@form[:instructor_id]}
          type="select"
          label={gettext("Assign Instructor")}
          options={@instructor_options}
          prompt={gettext("None (optional)")}
        />

        <div class="flex justify-end gap-3 pt-2">
          <button
            type="button"
            phx-click="close_program_form"
            class={[
              "px-4 py-2 border border-hero-grey-300 text-hero-charcoal",
              Theme.rounded(:lg),
              Theme.transition(:normal),
              "hover:bg-hero-grey-50"
            ]}
          >
            {gettext("Cancel")}
          </button>
          <button
            type="submit"
            id="save-program-btn"
            class={[
              "flex items-center gap-2 px-6 py-2.5 bg-hero-yellow hover:bg-hero-yellow-dark",
              "text-hero-charcoal font-semibold",
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            <.icon name="hero-check-mini" class="w-5 h-5" />
            {gettext("Save Program")}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp category_options do
    ProgramCategories.program_categories()
    |> Enum.map(fn cat -> {String.capitalize(cat), cat} end)
  end

  @doc """
  Renders an "Add" card with dashed border.

  ## Examples

      <.add_card_button label="Add Team Member" icon="hero-user-plus-mini" />
  """
  attr :label, :string, required: true
  attr :icon, :string, default: "hero-plus-mini"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click)

  def add_card_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "w-full h-full min-h-[200px] border-2 border-dashed border-hero-grey-300",
        "flex flex-col items-center justify-center gap-2",
        "text-hero-grey-400 hover:border-hero-cyan hover:text-hero-cyan",
        Theme.rounded(:xl),
        Theme.transition(:normal),
        @class
      ]}
      {@rest}
    >
      <.icon name={@icon} class="w-8 h-8" />
      <span class="font-medium">{@label}</span>
    </button>
    """
  end

  @doc """
  Renders the programs table with search and filters.

  ## Examples

      <.programs_table
        programs={@programs}
        staff_options={@staff_options}
        search_query=""
        selected_staff="all"
      />
  """
  attr :programs, :any, required: true, doc: "LiveView stream of programs"
  attr :staff_options, :list, required: true
  attr :search_query, :string, default: ""
  attr :selected_staff, :string, default: "all"

  def programs_table(assigns) do
    ~H"""
    <div class={["bg-white shadow-sm border border-hero-grey-200", Theme.rounded(:xl)]}>
      <div class="p-4 border-b border-hero-grey-200">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <h3 class="text-lg font-semibold text-hero-charcoal">
            {gettext("Program Inventory")}
          </h3>
          <div class="flex flex-col sm:flex-row gap-2">
            <div class="relative">
              <.icon
                name="hero-magnifying-glass-mini"
                class="w-5 h-5 text-hero-grey-400 absolute left-3 top-1/2 -translate-y-1/2"
              />
              <input
                type="text"
                name="search"
                value={@search_query}
                placeholder={gettext("Search by name...")}
                class={[
                  "pl-10 pr-4 py-2 w-full sm:w-64 border border-hero-grey-300 bg-white",
                  "text-sm placeholder-hero-grey-400 focus:border-hero-cyan focus:ring-1 focus:ring-hero-cyan",
                  Theme.rounded(:lg)
                ]}
                phx-change="search_programs"
                phx-debounce="300"
              />
            </div>
            <div class="relative">
              <.icon
                name="hero-funnel-mini"
                class="w-5 h-5 text-hero-grey-400 absolute left-3 top-1/2 -translate-y-1/2"
              />
              <select
                name="staff_filter"
                class={[
                  "pl-10 pr-8 py-2 w-full sm:w-40 border border-hero-grey-300 bg-white",
                  "text-sm focus:border-hero-cyan focus:ring-1 focus:ring-hero-cyan appearance-none",
                  Theme.rounded(:lg)
                ]}
                phx-change="filter_by_staff"
              >
                <option
                  :for={option <- @staff_options}
                  value={option.value}
                  selected={option.value == @selected_staff}
                >
                  {option.label}
                </option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-hero-grey-50 border-b border-hero-grey-200">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold text-hero-grey-500 uppercase tracking-wider">
                {gettext("Program Name")}
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-hero-grey-500 uppercase tracking-wider">
                {gettext("Assigned Staff")}
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-hero-grey-500 uppercase tracking-wider">
                {gettext("Status")}
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-hero-grey-500 uppercase tracking-wider">
                {gettext("Enrollment")}
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-hero-grey-500 uppercase tracking-wider">
                {gettext("Actions")}
              </th>
            </tr>
          </thead>
          <tbody id="programs-table-body" phx-update="stream" class="divide-y divide-hero-grey-200">
            <tr :for={{dom_id, program} <- @programs} id={dom_id} class="hover:bg-hero-grey-50">
              <td class="px-4 py-4">
                <div class="font-medium text-hero-charcoal">{program.name}</div>
                <div class="text-sm text-hero-grey-500">
                  {program.category} • €{program.price}
                </div>
              </td>
              <td class="px-4 py-4">
                <div :if={program.assigned_staff} class="flex items-center gap-2">
                  <div class={[
                    "w-8 h-8 flex items-center justify-center text-white text-xs font-medium",
                    Theme.rounded(:full),
                    Theme.gradient(:primary)
                  ]}>
                    {program.assigned_staff.initials}
                  </div>
                  <span class="text-sm text-hero-charcoal">{program.assigned_staff.name}</span>
                </div>
                <span :if={!program.assigned_staff} class="text-sm text-hero-grey-400 italic">
                  {gettext("Unassigned")}
                </span>
              </td>
              <td class="px-4 py-4">
                <.status_pill color={status_color(program.status)}>
                  {status_label(program.status)}
                </.status_pill>
              </td>
              <td class="px-4 py-4">
                <div class="flex items-center gap-3">
                  <div class="w-24 h-2 bg-hero-grey-200 rounded-full overflow-hidden">
                    <div
                      class="h-full bg-hero-cyan rounded-full"
                      style={"width: #{enrollment_percentage(program)}%"}
                    >
                    </div>
                  </div>
                  <span class="text-sm text-hero-grey-600">
                    {program.enrolled}/{program.capacity}
                  </span>
                </div>
              </td>
              <td class="px-4 py-4">
                <div class="flex items-center justify-end gap-1">
                  <.action_button icon="hero-eye-mini" title={gettext("Preview")} />
                  <.action_button icon="hero-user-group-mini" title={gettext("View Roster")} />
                  <.action_button icon="hero-pencil-square-mini" title={gettext("Edit")} />
                  <.action_button icon="hero-document-duplicate-mini" title={gettext("Duplicate")} />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp status_color(:active), do: "success"
  defp status_color(:pending), do: "warning"
  defp status_color(:inactive), do: "error"
  defp status_color(_), do: "info"

  defp status_label(:active), do: gettext("Active")
  defp status_label(:pending), do: gettext("Pending")
  defp status_label(:inactive), do: gettext("Inactive")
  defp status_label(_), do: gettext("Unknown")

  defp enrollment_percentage(program) do
    if program.capacity > 0 do
      min(100, div(program.enrolled * 100, program.capacity))
    else
      0
    end
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :rest, :global, include: ~w(phx-click phx-value-id)

  defp action_button(assigns) do
    ~H"""
    <button
      type="button"
      title={@title}
      class={[
        "p-2 text-hero-grey-400 hover:text-hero-charcoal hover:bg-hero-grey-100",
        Theme.rounded(:lg),
        Theme.transition(:normal)
      ]}
      {@rest}
    >
      <.icon name={@icon} class="w-5 h-5" />
    </button>
    """
  end

  @doc """
  Converts a Phoenix upload error atom to a human-readable string.
  """
  def upload_error_to_string(:too_large), do: gettext("File is too large.")
  def upload_error_to_string(:too_many_files), do: gettext("Too many files.")
  def upload_error_to_string(:not_accepted), do: gettext("File type not accepted.")
  def upload_error_to_string(_), do: gettext("Upload error.")

  @doc """
  Renders the verification documents panel for the edit profile page.

  Includes the list of existing documents (as a stream) and the upload form.
  """
  attr :verification_docs, :any, required: true, doc: "LiveView stream of verification documents"
  attr :uploads, :map, required: true, doc: "The @uploads assign from the parent LiveView"
  attr :doc_type, :string, required: true, doc: "Currently selected document type"

  def verification_documents_panel(assigns) do
    ~H"""
    <div class={["bg-white p-6 shadow-sm border border-hero-grey-200", Theme.rounded(:xl)]}>
      <h2 class="text-lg font-semibold text-hero-charcoal mb-4">
        {gettext("Verification Documents")}
      </h2>
      <p class="text-sm text-hero-grey-500 mb-6">
        {gettext("Upload documents to verify your business. Documents are reviewed by our team.")}
      </p>

      <%!-- Existing Documents --%>
      <div id="verification-docs" phx-update="stream" class="space-y-3 mb-6">
        <div id="vdoc-empty" class="hidden only:block text-sm text-hero-grey-400 italic py-4">
          {gettext("No documents uploaded yet.")}
        </div>
        <div
          :for={{id, doc} <- @verification_docs}
          id={id}
          class={[
            "flex items-center justify-between p-4 border border-hero-grey-200",
            Theme.rounded(:lg)
          ]}
        >
          <div class="flex items-center gap-3">
            <.icon name="hero-document-text-mini" class="w-5 h-5 text-hero-grey-400" />
            <div>
              <p class="text-sm font-medium text-hero-charcoal">
                {ProviderPresenter.document_type_label(doc.document_type)}
              </p>
              <p class="text-xs text-hero-grey-500">{doc.original_filename}</p>
            </div>
          </div>
          <.doc_status_badge status={doc.status} />
        </div>
      </div>

      <%!-- Upload New Document --%>
      <div class={[
        "border-t border-hero-grey-200 pt-6"
      ]}>
        <h3 class="text-sm font-semibold text-hero-charcoal mb-3">
          {gettext("Upload New Document")}
        </h3>

        <form
          id="doc-upload-form"
          phx-submit="upload_verification_doc"
          phx-change="validate_upload"
          class="space-y-4"
        >
          <div>
            <label class="block text-sm font-medium text-hero-grey-700 mb-1">
              {gettext("Document Type")}
            </label>
            <select
              name="doc_type"
              id="doc-type-select"
              phx-change="select_doc_type"
              class={[
                "w-full sm:w-64 px-3 py-2 border border-hero-grey-300 bg-white",
                "text-sm focus:border-hero-cyan focus:ring-1 focus:ring-hero-cyan",
                Theme.rounded(:lg)
              ]}
            >
              <option
                :for={type <- VerificationDocument.valid_document_types()}
                value={type}
                selected={type == @doc_type}
              >
                {ProviderPresenter.document_type_label(type)}
              </option>
            </select>
          </div>

          <div>
            <.live_file_input upload={@uploads.verification_doc} class="hidden" />
            <label
              for={@uploads.verification_doc.ref}
              class={[
                "inline-flex items-center gap-2 px-4 py-2 border border-hero-grey-300",
                "bg-white hover:bg-hero-grey-50 text-hero-charcoal text-sm font-medium cursor-pointer",
                Theme.rounded(:lg),
                Theme.transition(:normal)
              ]}
            >
              <.icon name="hero-document-plus-mini" class="w-4 h-4" />
              {gettext("Select File")}
            </label>
            <p class="text-xs text-hero-grey-400 mt-2">
              {gettext("PDF, JPG or PNG. Max 10MB.")}
            </p>
            <div
              :for={entry <- @uploads.verification_doc.entries}
              class={[
                "flex items-center gap-3 mt-3 px-3 py-2 border border-hero-grey-200",
                "bg-hero-grey-50",
                Theme.rounded(:lg)
              ]}
            >
              <.icon name="hero-document-text-mini" class="w-5 h-5 text-hero-grey-500 shrink-0" />
              <span class="text-sm text-hero-charcoal truncate flex-1">{entry.client_name}</span>
              <button
                type="button"
                phx-click="cancel_upload"
                phx-value-ref={entry.ref}
                phx-value-upload="verification_doc"
                class="text-xs text-red-500 hover:text-red-700 shrink-0"
              >
                {gettext("Remove")}
              </button>
              <div
                :for={err <- upload_errors(@uploads.verification_doc, entry)}
                class="text-xs text-red-500"
              >
                {upload_error_to_string(err)}
              </div>
            </div>
          </div>

          <button
            type="submit"
            id="upload-doc-btn"
            disabled={@uploads.verification_doc.entries == []}
            class={[
              "flex items-center gap-2 px-4 py-2 border border-hero-grey-300",
              "bg-white hover:bg-hero-grey-50 text-hero-charcoal text-sm font-medium",
              "disabled:opacity-50 disabled:cursor-not-allowed",
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            <.icon name="hero-arrow-up-tray-mini" class="w-4 h-4" />
            {gettext("Upload Document")}
          </button>
        </form>
      </div>
    </div>
    """
  end
end
