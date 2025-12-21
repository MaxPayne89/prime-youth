defmodule PrimeYouthWeb.UserLive.Registration do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Accounts
  alias PrimeYouth.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Register for an account
            <:subtitle>
              Already registered?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                Log in
              </.link>
              to your account now.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:name]}
            type="text"
            label="Name"
            autocomplete="name"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
          />

          <fieldset class="mt-6">
            <legend class="text-sm font-semibold leading-6 text-zinc-800">I want to...</legend>
            <p class="mt-1 text-sm text-zinc-500">Select one or both options</p>
            <div class="mt-3 space-y-3">
              <label class="flex items-start gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  name="user[intended_roles][]"
                  value="parent"
                  checked={:parent in (@form[:intended_roles].value || [])}
                  class="mt-1 rounded border-2 border-zinc-400 text-cyan-600 focus:ring-2 focus:ring-cyan-500/20 focus:ring-offset-0 shadow-sm transition-all duration-200"
                />
                <div>
                  <span class="font-medium text-zinc-900">Enroll children in programs</span>
                  <p class="text-sm text-zinc-500">
                    Find and book activities, camps, and classes for your children
                  </p>
                </div>
              </label>
              <label class="flex items-start gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  name="user[intended_roles][]"
                  value="provider"
                  checked={:provider in (@form[:intended_roles].value || [])}
                  class="mt-1 rounded border-2 border-zinc-400 text-cyan-600 focus:ring-2 focus:ring-cyan-500/20 focus:ring-offset-0 shadow-sm transition-all duration-200"
                />
                <div>
                  <span class="font-medium text-zinc-900">Offer programs and services</span>
                  <p class="text-sm text-zinc-500">
                    Create and manage programs, activities, and services for families
                  </p>
                </div>
              </label>
            </div>
            <.error :for={msg <- Enum.map(@form[:intended_roles].errors, &translate_error/1)}>
              {msg}
            </.error>
          </fieldset>

          <.button phx-disable-with="Creating account..." class="btn btn-primary w-full mt-6">
            Create an account
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: PrimeYouthWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
