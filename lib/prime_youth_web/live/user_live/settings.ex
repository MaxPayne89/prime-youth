defmodule PrimeYouthWeb.UserLive.Settings do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Auth.Adapters.Driven.Persistence.Schemas.UserSchema, as: User
  alias PrimeYouth.Auth.Application.UseCases.RequestEmailChange
  alias PrimeYouth.Auth.Queries

  on_mount {PrimeYouthWeb.UserAuth, :require_sudo_mode}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400 p-6">
      <div class="max-w-2xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8 pt-6">
          <div class="inline-flex items-center justify-center w-16 h-16 bg-white rounded-full shadow-lg mb-4">
            <div class="w-10 h-10 bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 rounded-lg flex items-center justify-center">
              <span class="text-white font-bold text-lg">⚙️</span>
            </div>
          </div>
          <h1 class="text-3xl font-bold text-white mb-2">Account Settings</h1>
          <p class="text-white/80">Manage your account email address and password</p>
        </div>
        
    <!-- Email Change Section -->
        <div class="bg-white/25 backdrop-blur-lg border border-white/[0.18] rounded-2xl p-6 mb-6">
          <h2 class="text-xl font-bold text-white mb-4">Change Email</h2>

          <.form
            :let={f}
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
            class="space-y-4"
          >
            <div class="space-y-2">
              <label for="email-input" class="block text-sm font-medium text-white">
                New Email Address
              </label>
              <input
                type="email"
                id="email-input"
                name={f[:email].name}
                value={Phoenix.HTML.Form.normalize_value("email", f[:email].value)}
                placeholder="new@email.com"
                required
                autocomplete="username"
                class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
              />
              <%= if f[:email].errors != [] do %>
                <p class="text-red-200 text-sm mt-1">
                  {Enum.map_join(
                    f[:email].errors,
                    ", ",
                    &PrimeYouthWeb.CoreComponents.translate_error/1
                  )}
                </p>
              <% end %>
            </div>

            <button
              type="submit"
              phx-disable-with="Sending confirmation email..."
              class="w-full bg-white text-gray-900 py-3 px-4 rounded-xl font-semibold hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-white/50 transform hover:scale-105 transition-all duration-200 shadow-lg"
            >
              Change Email
            </button>
          </.form>
        </div>
        
    <!-- Password Change Section -->
        <div class="bg-white/25 backdrop-blur-lg border border-white/[0.18] rounded-2xl p-6">
          <h2 class="text-xl font-bold text-white mb-4">Change Password</h2>

          <.form
            :let={f}
            for={@password_form}
            id="password_form"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
            class="space-y-4"
          >
            <input
              name={f[:email].name}
              type="hidden"
              id="hidden_user_email"
              autocomplete="username"
              value={@current_email}
            />

            <div class="space-y-2">
              <label for="current-password" class="block text-sm font-medium text-white">
                Current Password
              </label>
              <input
                type="password"
                id="current-password"
                name={f[:current_password].name}
                placeholder="Enter current password"
                required
                autocomplete="current-password"
                class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
              />
              <%= if f[:current_password].errors != [] do %>
                <p class="text-red-200 text-sm mt-1">
                  {Enum.map_join(
                    f[:current_password].errors,
                    ", ",
                    &PrimeYouthWeb.CoreComponents.translate_error/1
                  )}
                </p>
              <% end %>
            </div>

            <div class="space-y-2">
              <label for="new-password" class="block text-sm font-medium text-white">
                New Password
              </label>
              <input
                type="password"
                id="new-password"
                name={f[:password].name}
                placeholder="Enter new password (at least 12 characters)"
                required
                autocomplete="new-password"
                class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
              />
              <%= if f[:password].errors != [] do %>
                <p class="text-red-200 text-sm mt-1">
                  {Enum.map_join(
                    f[:password].errors,
                    ", ",
                    &PrimeYouthWeb.CoreComponents.translate_error/1
                  )}
                </p>
              <% end %>
            </div>

            <div class="space-y-2">
              <label for="confirm-password" class="block text-sm font-medium text-white">
                Confirm New Password
              </label>
              <input
                type="password"
                id="confirm-password"
                name={f[:password_confirmation].name}
                placeholder="Confirm new password"
                required
                autocomplete="new-password"
                class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
              />
              <%= if f[:password_confirmation].errors != [] do %>
                <p class="text-red-200 text-sm mt-1">
                  {Enum.map_join(
                    f[:password_confirmation].errors,
                    ", ",
                    &PrimeYouthWeb.CoreComponents.translate_error/1
                  )}
                </p>
              <% end %>
            </div>

            <button
              type="submit"
              phx-disable-with="Saving password..."
              class="w-full bg-white text-gray-900 py-3 px-4 rounded-xl font-semibold hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-white/50 transform hover:scale-105 transition-all duration-200 shadow-lg"
            >
              Save Password
            </button>
          </.form>
        </div>
        
    <!-- Back to Home -->
        <div class="text-center mt-6">
          <.link
            navigate={~p"/"}
            class="text-white/80 text-sm hover:text-white transition-colors inline-flex items-center gap-2"
          >
            <span>←</span> Back to Home
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    user = socket.assigns.current_scope.user
    repo = Application.fetch_env!(:prime_youth, :repository)

    socket =
      case repo.verify_email_token(token, :change_email) do
        {:ok, verified_user} ->
          if verified_user.id == user.id do
            case repo.update_email(user, verified_user.email) do
              {:ok, updated_user} ->
                # Delete the email change token after successful update
                repo.delete_email_tokens_for_user(updated_user, :change_email)
                put_flash(socket, :info, "Email changed successfully.")

              {:error, _} ->
                put_flash(socket, :error, "Failed to update email.")
            end
          else
            put_flash(socket, :error, "Email change link is invalid.")
          end

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = User.email_changeset(%User{email: user.email}, %{})
    password_changeset = User.password_changeset(%User{}, %{})

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset, as: "user"))
      |> assign(:password_form, to_form(password_changeset, as: "user"))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    email_form =
      %User{email: user.email}
      |> User.email_changeset(user_params)
      |> Map.put(:action, :validate)
      |> to_form(as: "user")

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => %{"email" => new_email}} = params
    user = socket.assigns.current_scope.user
    true = Queries.sudo_mode?(user, -10)

    # Validate the changeset first to catch "did not change" error
    changeset =
      %User{email: user.email}
      |> User.email_changeset(%{email: new_email})
      |> Map.put(:action, :validate)

    case Ecto.Changeset.apply_action(changeset, :validate) do
      {:ok, _} ->
        # Changeset is valid, proceed with RequestEmailChange use case
        case RequestEmailChange.execute(%{user_id: user.id, new_email: new_email}) do
          {:ok, %{new_email: validated_email}} ->
            info = "A link to confirm your email change has been sent to #{validated_email}."
            {:noreply, put_flash(socket, :info, info)}

          {:error, :invalid_email} ->
            changeset =
              changeset
              |> Ecto.Changeset.add_error(:email, "is invalid")

            {:noreply, assign(socket, :email_form, to_form(changeset, as: "user"))}

          {:error, :email_taken} ->
            changeset =
              changeset
              |> Ecto.Changeset.add_error(:email, "has already been taken")

            {:noreply, assign(socket, :email_form, to_form(changeset, as: "user"))}

          {:error, _} ->
            {:noreply,
             put_flash(socket, :error, "Failed to send confirmation email. Please try again.")}
        end

      {:error, invalid_changeset} ->
        # Changeset validation failed (e.g., "did not change")
        {:noreply, assign(socket, :email_form, to_form(invalid_changeset, as: "user"))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      %User{}
      |> User.password_changeset(user_params)
      |> Map.put(:action, :validate)
      |> to_form(as: "user")

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Queries.sudo_mode?(user, -10)

    changeset = User.password_changeset(%User{}, user_params)

    case Ecto.Changeset.apply_action(changeset, :validate) do
      {:ok, _} ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset, as: "user"))}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset, as: "user", action: :validate))}
    end
  end
end
