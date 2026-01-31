defmodule KlassHeroWeb.Settings.ChildrenLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.Identity
  alias KlassHeroWeb.Helpers.IdentityHelpers
  alias KlassHeroWeb.Presenters.ChildPresenter
  alias KlassHeroWeb.Theme

  require Logger

  @consent_type "provider_data_sharing"

  @impl true
  def mount(_params, _session, socket) do
    case IdentityHelpers.get_parent_for_current_user(socket) do
      {:ok, parent} ->
        children = Identity.get_children(parent.id)

        children_count = length(children)

        socket =
          socket
          |> assign(page_title: gettext("Children Profiles"))
          |> assign(parent_id: parent.id)
          |> assign(children_count: children_count)
          |> assign(children_empty?: children_count == 0)
          |> stream(:children, Enum.map(children, &child_view_data/1))

        {:ok, socket}

      {:error, :no_parent} ->
        socket =
          socket
          |> put_flash(:error, gettext("Please set up your parent profile to manage children."))
          |> redirect(to: ~p"/settings")

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(show_modal: false)
    |> assign(child: nil)
    |> assign(form: nil)
    |> assign(consent_checked: false)
  end

  defp apply_action(socket, :new, _params) do
    changeset = Identity.change_child()

    socket
    |> assign(show_modal: true)
    |> assign(child: nil)
    |> assign(form: to_form(changeset, as: :child))
    |> assign(consent_checked: false)
  end

  defp apply_action(socket, :edit, %{"child_id" => child_id}) do
    case Identity.get_child_by_id(child_id) do
      {:ok, child} ->
        # Trigger: verify child belongs to the current parent
        # Why: prevent editing another parent's children
        # Outcome: redirect unauthorized users back to index
        if child.parent_id == socket.assigns.parent_id do
          changeset = Identity.change_child(child, %{})
          consent = Identity.child_has_active_consent?(child.id, @consent_type)

          socket
          |> assign(show_modal: true)
          |> assign(child: child)
          |> assign(form: to_form(changeset, as: :child))
          |> assign(consent_checked: consent)
        else
          socket
          |> put_flash(:error, gettext("You don't have permission to edit this child."))
          |> push_patch(to: ~p"/settings/children")
        end

      {:error, :not_found} ->
        socket
        |> put_flash(:error, gettext("Child not found."))
        |> push_patch(to: ~p"/settings/children")
    end
  end

  @impl true
  def handle_event("validate_child", %{"child" => child_params}, socket) do
    changeset =
      if socket.assigns.child do
        Identity.change_child(socket.assigns.child, child_params)
      else
        Identity.change_child(child_params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :child))}
  end

  def handle_event("toggle_consent", %{"value" => "true"}, socket) do
    {:noreply, assign(socket, consent_checked: true)}
  end

  def handle_event("toggle_consent", _params, socket) do
    {:noreply, assign(socket, consent_checked: false)}
  end

  def handle_event("save_child", %{"child" => child_params}, socket) do
    save_child(socket, socket.assigns.live_action, child_params)
  end

  def handle_event("delete_child", %{"id" => child_id}, socket) do
    # Trigger: verify child belongs to current parent before deleting
    # Why: prevent unauthorized deletion
    # Outcome: only delete if ownership confirmed
    if Identity.child_belongs_to_parent?(child_id, socket.assigns.parent_id) do
      case Identity.delete_child(child_id) do
        :ok ->
          new_count = socket.assigns.children_count - 1

          {:noreply,
           socket
           |> stream_delete_by_dom_id(:children, "children-#{child_id}")
           |> assign(children_count: new_count)
           |> assign(children_empty?: new_count == 0)
           |> put_flash(:info, gettext("Child removed successfully."))}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, gettext("Child not found."))}

        {:error, _reason} ->
          {:noreply,
           put_flash(socket, :error, gettext("Could not remove child. Please try again."))}
      end
    else
      {:noreply,
       put_flash(socket, :error, gettext("You don't have permission to delete this child."))}
    end
  end

  defp save_child(socket, :new, child_params) do
    # Trigger: validate via changeset before calling domain layer
    # Why: domain layer expects atom keys and typed values; changeset catches form errors first
    # Outcome: user sees field-level errors if validation fails
    changeset =
      child_params
      |> Identity.change_child()
      |> Map.put(:action, :validate)

    if changeset.valid? do
      attrs =
        child_params
        |> atomize_keys()
        |> Map.put(:parent_id, socket.assigns.parent_id)

      case Identity.create_child(attrs) do
        {:ok, child} ->
          consent_result =
            handle_consent_change(
              child.id,
              socket.assigns.parent_id,
              socket.assigns.consent_checked
            )

          new_count = socket.assigns.children_count + 1

          {:noreply,
           socket
           |> stream_insert(:children, child_view_data(child))
           |> assign(children_count: new_count)
           |> assign(children_empty?: false)
           |> put_flash(:info, child_saved_flash(:new, consent_result))
           |> push_patch(to: ~p"/settings/children")}

        {:error, %Ecto.Changeset{} = cs} ->
          {:noreply, assign(socket, form: to_form(cs, as: :child))}

        {:error, {:validation_error, _errors}} ->
          {:noreply, put_flash(socket, :error, gettext("Please check the form for errors."))}

        {:error, reason} ->
          Logger.error("Unexpected error saving child: #{inspect(reason)}")

          {:noreply,
           put_flash(socket, :error, gettext("An unexpected error occurred. Please try again."))}
      end
    else
      {:noreply, assign(socket, form: to_form(changeset, as: :child))}
    end
  end

  defp save_child(socket, :edit, child_params) do
    child = socket.assigns.child

    changeset =
      child
      |> Identity.change_child(child_params)
      |> Map.put(:action, :validate)

    if changeset.valid? do
      attrs = atomize_keys(child_params)

      case Identity.update_child(child.id, attrs) do
        {:ok, updated_child} ->
          consent_result =
            handle_consent_change(
              updated_child.id,
              socket.assigns.parent_id,
              socket.assigns.consent_checked
            )

          {:noreply,
           socket
           |> stream_insert(:children, child_view_data(updated_child))
           |> put_flash(:info, child_saved_flash(:edit, consent_result))
           |> push_patch(to: ~p"/settings/children")}

        {:error, %Ecto.Changeset{} = cs} ->
          {:noreply, assign(socket, form: to_form(cs, as: :child))}

        {:error, {:validation_error, _errors}} ->
          {:noreply, put_flash(socket, :error, gettext("Please check the form for errors."))}

        {:error, reason} ->
          Logger.error("Unexpected error saving child: #{inspect(reason)}")

          {:noreply,
           put_flash(socket, :error, gettext("An unexpected error occurred. Please try again."))}
      end
    else
      {:noreply, assign(socket, form: to_form(changeset, as: :child))}
    end
  end

  defp handle_consent_change(child_id, parent_id, consent_checked) do
    current_consent = Identity.child_has_active_consent?(child_id, @consent_type)

    result =
      cond do
        consent_checked and not current_consent ->
          Identity.grant_consent(%{
            parent_id: parent_id,
            child_id: child_id,
            consent_type: @consent_type
          })

        not consent_checked and current_consent ->
          Identity.withdraw_consent(child_id, @consent_type)

        true ->
          :noop
      end

    case result do
      {:ok, _} ->
        :ok

      :noop ->
        :ok

      {:error, reason} ->
        Logger.error("Consent update failed for child #{child_id}: #{inspect(reason)}")
        {:error, :consent_failed}
    end
  end

  defp child_saved_flash(:new, :ok), do: gettext("Child added successfully.")

  defp child_saved_flash(:new, {:error, _}),
    do: gettext("Child added, but consent update failed. Please try again.")

  defp child_saved_flash(:edit, :ok), do: gettext("Child updated successfully.")

  defp child_saved_flash(:edit, {:error, _}),
    do: gettext("Child updated, but consent update failed. Please try again.")

  defp child_view_data(child) do
    simple = ChildPresenter.to_simple_view(child)
    consent = Identity.child_has_active_consent?(child.id, @consent_type)

    Map.merge(simple, %{
      date_of_birth: child.date_of_birth,
      emergency_contact: child.emergency_contact,
      support_needs: child.support_needs,
      allergies: child.allergies,
      consent_active: consent
    })
  end

  @allowed_keys ~w(first_name last_name date_of_birth emergency_contact support_needs allergies)a

  defp atomize_keys(params) when is_map(params) do
    for key <- @allowed_keys,
        Map.has_key?(params, to_string(key)),
        into: %{} do
      {key, coerce_value(key, Map.get(params, to_string(key)))}
    end
  end

  # Trigger: form sends date_of_birth as ISO 8601 string
  # Why: domain model validates %Date{} struct, not strings
  # Outcome: parse string to Date before passing to domain layer
  defp coerce_value(:date_of_birth, value) when is_binary(value) and value != "" do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp coerce_value(_key, value), do: value

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", Theme.bg(:muted)]}>
      <.page_header variant={:dark} size={:large} centered container_class="max-w-7xl mx-auto">
        <:title>{gettext("Children Profiles")}</:title>
        <:subtitle>{gettext("Manage your children's information and consents")}</:subtitle>
      </.page_header>

      <div class="max-w-4xl mx-auto p-4 space-y-4">
        <div class="flex items-center justify-between mb-4">
          <.link
            navigate={~p"/settings"}
            class={[
              "inline-flex items-center gap-1 text-sm font-medium",
              Theme.text_color(:primary),
              "hover:underline"
            ]}
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            {gettext("Back to Settings")}
          </.link>

          <.link
            id="add-child-btn"
            patch={~p"/settings/children/new"}
            class={[
              "inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white",
              "bg-hero-blue-600 hover:bg-hero-blue-700",
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            <.icon name="hero-plus" class="w-4 h-4" />
            {gettext("Add Child")}
          </.link>
        </div>

        <%= if @children_empty? do %>
          <.empty_state
            icon="hero-user-group"
            title={gettext("No children yet")}
            description={gettext("Add your first child to get started with activities and programs.")}
            data_testid="no-children-state"
          >
            <:action>
              <.link
                patch={~p"/settings/children/new"}
                class={[
                  "inline-flex items-center gap-2 px-4 py-2 mt-4 text-sm font-semibold text-white",
                  "bg-hero-blue-600 hover:bg-hero-blue-700",
                  Theme.rounded(:lg),
                  Theme.transition(:normal)
                ]}
              >
                <.icon name="hero-plus" class="w-4 h-4" />
                {gettext("Add Child")}
              </.link>
            </:action>
          </.empty_state>
        <% end %>

        <div id="children-list" phx-update="stream">
          <div
            :for={{dom_id, child} <- @streams.children}
            id={dom_id}
            class={[
              Theme.bg(:surface),
              "shadow-sm border overflow-hidden",
              Theme.rounded(:xl),
              Theme.border_color(:light),
              "p-4"
            ]}
          >
            <div class="flex items-start justify-between">
              <div class="flex items-center gap-3">
                <div class={[
                  "w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-lg",
                  Theme.gradient(:primary)
                ]}>
                  {String.first(child.name)}
                </div>
                <div>
                  <h3 class={["font-semibold", Theme.text_color(:heading)]}>
                    {child.name}
                  </h3>
                  <p class="text-sm text-hero-grey-500">
                    {gettext("%{age} years old", age: child.age)}
                    <%= if child.date_of_birth do %>
                      <span class="mx-1">&bull;</span>
                      {Calendar.strftime(child.date_of_birth, "%B %d, %Y")}
                    <% end %>
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-2">
                <.link
                  patch={~p"/settings/children/#{child.id}/edit"}
                  class={[
                    "p-2 text-hero-grey-400 hover:text-hero-blue-600",
                    Theme.rounded(:lg),
                    "hover:bg-hero-grey-50",
                    Theme.transition(:normal)
                  ]}
                  title={gettext("Edit")}
                >
                  <.icon name="hero-pencil-square" class="w-5 h-5" />
                </.link>
                <button
                  type="button"
                  phx-click="delete_child"
                  phx-value-id={child.id}
                  data-confirm={gettext("Are you sure you want to remove this child?")}
                  class={[
                    "p-2 text-hero-grey-400 hover:text-red-600",
                    Theme.rounded(:lg),
                    "hover:bg-red-50",
                    Theme.transition(:normal)
                  ]}
                  title={gettext("Delete")}
                >
                  <.icon name="hero-trash" class="w-5 h-5" />
                </button>
              </div>
            </div>

            <%!-- Optional details --%>
            <div class="mt-3 flex flex-wrap gap-2">
              <%= if child.consent_active do %>
                <span class={[
                  "inline-flex items-center gap-1 px-2 py-1 text-xs font-medium",
                  "bg-green-100 text-green-700",
                  Theme.rounded(:full)
                ]}>
                  <.icon name="hero-check-circle-mini" class="w-3 h-3" />
                  {gettext("Data sharing consent")}
                </span>
              <% end %>

              <%= if child.emergency_contact do %>
                <span class={[
                  "inline-flex items-center gap-1 px-2 py-1 text-xs font-medium",
                  "bg-blue-100 text-blue-700",
                  Theme.rounded(:full)
                ]}>
                  <.icon name="hero-phone-mini" class="w-3 h-3" />
                  {gettext("Emergency contact")}
                </span>
              <% end %>

              <%= if child.allergies do %>
                <span class={[
                  "inline-flex items-center gap-1 px-2 py-1 text-xs font-medium",
                  "bg-orange-100 text-orange-700",
                  Theme.rounded(:full)
                ]}>
                  <.icon name="hero-exclamation-triangle-mini" class="w-3 h-3" />
                  {gettext("Allergies")}
                </span>
              <% end %>

              <%= if child.support_needs do %>
                <span class={[
                  "inline-flex items-center gap-1 px-2 py-1 text-xs font-medium",
                  "bg-purple-100 text-purple-700",
                  Theme.rounded(:full)
                ]}>
                  <.icon name="hero-heart-mini" class="w-3 h-3" />
                  {gettext("Support needs")}
                </span>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <%!-- Add/Edit Modal --%>
      <%= if @show_modal do %>
        <div
          id="child-modal-backdrop"
          class="fixed inset-0 z-50 bg-black/50"
          phx-click={JS.patch(~p"/settings/children")}
        >
        </div>
        <div
          id="child-modal"
          class={[
            "fixed inset-x-4 top-[5%] z-50 mx-auto max-w-lg",
            Theme.bg(:surface),
            Theme.rounded(:xl),
            "shadow-xl max-h-[90vh] overflow-y-auto"
          ]}
          phx-click-away={JS.patch(~p"/settings/children")}
        >
          <div class="flex items-center justify-between p-4 border-b border-hero-grey-200">
            <h2 class={["text-lg font-semibold", Theme.text_color(:heading)]}>
              <%= if @live_action == :new do %>
                {gettext("Add Child")}
              <% else %>
                {gettext("Edit Child")}
              <% end %>
            </h2>
            <.link
              patch={~p"/settings/children"}
              class="p-1 text-hero-grey-400 hover:text-hero-grey-600"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </.link>
          </div>

          <div class="p-4">
            <.form
              for={@form}
              id="child-form"
              phx-change="validate_child"
              phx-submit="save_child"
              class="space-y-4"
            >
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <.input
                  field={@form[:first_name]}
                  type="text"
                  label={gettext("First name")}
                  required
                />
                <.input
                  field={@form[:last_name]}
                  type="text"
                  label={gettext("Last name")}
                  required
                />
              </div>

              <.input
                field={@form[:date_of_birth]}
                type="date"
                label={gettext("Date of birth")}
                required
              />

              <.input
                field={@form[:emergency_contact]}
                type="text"
                label={gettext("Emergency contact")}
                placeholder={gettext("Phone number or name")}
              />

              <.input
                field={@form[:allergies]}
                type="textarea"
                label={gettext("Allergies")}
                placeholder={gettext("List any known allergies...")}
              />

              <.input
                field={@form[:support_needs]}
                type="textarea"
                label={gettext("Support needs")}
                placeholder={gettext("Any special accommodations or support needs...")}
              />

              <div class="border-t border-hero-grey-200 pt-4">
                <label class="flex items-start gap-3 cursor-pointer">
                  <input
                    type="checkbox"
                    id="consent-checkbox"
                    name="consent"
                    value="true"
                    checked={@consent_checked}
                    phx-click="toggle_consent"
                    class="mt-1 rounded border-2 border-hero-grey-300 text-hero-blue-600 focus:ring-2 focus:ring-hero-blue-500/20"
                  />
                  <div>
                    <span class="text-sm font-medium text-hero-black">
                      {gettext("Provider data sharing consent")}
                    </span>
                    <p class="text-xs text-hero-grey-500 mt-1">
                      {gettext(
                        "Allow activity providers to access this child's profile information for program participation."
                      )}
                    </p>
                  </div>
                </label>
              </div>

              <div class="flex justify-end gap-3 pt-4">
                <.link
                  patch={~p"/settings/children"}
                  class={[
                    "px-4 py-2 text-sm font-medium text-hero-grey-700",
                    "bg-hero-grey-100 hover:bg-hero-grey-200",
                    Theme.rounded(:lg),
                    Theme.transition(:normal)
                  ]}
                >
                  {gettext("Cancel")}
                </.link>
                <button
                  type="submit"
                  id="save-child-btn"
                  phx-disable-with={gettext("Saving...")}
                  class={[
                    "px-4 py-2 text-sm font-semibold text-white",
                    "bg-hero-blue-600 hover:bg-hero-blue-700",
                    Theme.rounded(:lg),
                    Theme.transition(:normal)
                  ]}
                >
                  <%= if @live_action == :new do %>
                    {gettext("Add Child")}
                  <% else %>
                    {gettext("Save Changes")}
                  <% end %>
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
