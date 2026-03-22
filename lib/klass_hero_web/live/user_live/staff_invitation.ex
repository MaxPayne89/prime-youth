defmodule KlassHeroWeb.UserLive.StaffInvitation do
  use KlassHeroWeb, :live_view

  alias KlassHero.Accounts
  alias KlassHero.Accounts.User
  alias KlassHero.Provider
  alias KlassHero.Provider.Domain.Models.StaffMember

  @invitation_expiry_days 7

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <%= cond do %>
          <% @error == :invalid -> %>
            <div class="text-center">
              <.header>
                {gettext("Invalid Invitation")}
                <:subtitle>
                  {gettext("This invitation link is invalid or has already been used.")}
                </:subtitle>
              </.header>
              <.link navigate={~p"/"} class="btn btn-primary mt-6">
                {gettext("Go to Home")}
              </.link>
            </div>
          <% @error == :expired -> %>
            <div class="text-center">
              <.header>
                {gettext("Invitation Expired")}
                <:subtitle>
                  {gettext("This invitation has expired. Please ask your business to resend it.")}
                </:subtitle>
              </.header>
              <.link navigate={~p"/"} class="btn btn-primary mt-6">
                {gettext("Go to Home")}
              </.link>
            </div>
          <% true -> %>
            <div class="text-center">
              <.header>
                {gettext("Complete Your Registration")}
                <:subtitle>
                  {gettext("You've been invited to join a team on Klass Hero.")}
                </:subtitle>
              </.header>
            </div>

            <.form for={@form} id="staff-registration-form" phx-submit="save" phx-change="validate">
              <.input
                field={@form[:name]}
                type="text"
                label={gettext("Name")}
                autocomplete="name"
                required
              />
              <.input
                field={@form[:email]}
                type="email"
                label={gettext("Email")}
                autocomplete="username"
                required
                readonly
              />
              <.input
                field={@form[:password]}
                type="password"
                label={gettext("Password")}
                autocomplete="new-password"
                required
              />
              <.button
                phx-disable-with={gettext("Creating account...")}
                class="btn btn-primary w-full mt-6"
              >
                {gettext("Complete Registration")}
              </.button>
            </.form>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => raw_token}, _session, socket) do
    with {:ok, decoded} <- Base.url_decode64(raw_token, padding: false),
         token_hash = :crypto.hash(:sha256, decoded),
         {:ok, staff_member} <- Provider.get_staff_member_by_token_hash(token_hash) do
      if invitation_expired?(staff_member) do
        # Only expire in the connected phase to avoid double-mutation across static/WS mount
        if connected?(socket), do: Provider.expire_staff_invitation(staff_member.id)
        {:ok, assign(socket, error: :expired, form: nil, staff_member: nil)}
      else
        changeset =
          User.staff_registration_changeset(
            %User{},
            %{
              "name" => StaffMember.full_name(staff_member),
              "email" => staff_member.email
            },
            validate_unique: false
          )

        {:ok,
         socket
         |> assign(
           staff_member: staff_member,
           error: nil,
           page_title: gettext("Complete Registration")
         )
         |> assign_form(changeset), temporary_assigns: [form: nil]}
      end
    else
      _ -> {:ok, assign(socket, error: :invalid, form: nil, staff_member: nil)}
    end
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    staff = socket.assigns.staff_member

    # Merge the staff email (readonly field) into params so it cannot be tampered with
    params = Map.put(user_params, "email", staff.email)

    case Accounts.register_staff_user(params) do
      {:ok, user} ->
        Accounts.emit_staff_user_registered(user.id, staff.id, staff.provider_id)

        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(:info, gettext("Account created! Check your email to confirm and log in."))
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    staff = socket.assigns.staff_member
    params = Map.put(user_params, "email", staff.email)

    changeset =
      User.staff_registration_changeset(%User{}, params, validate_unique: false)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp invitation_expired?(%StaffMember{invitation_sent_at: nil}), do: false

  defp invitation_expired?(%StaffMember{invitation_sent_at: sent_at}) do
    DateTime.diff(DateTime.utc_now(), sent_at, :day) >= @invitation_expiry_days
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "user"))
  end
end
