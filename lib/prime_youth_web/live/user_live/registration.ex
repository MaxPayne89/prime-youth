defmodule PrimeYouthWeb.UserLive.Registration do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Auth.Adapters.Driven.Persistence.Schemas.UserSchema, as: User
  alias PrimeYouth.Auth.Application.UseCases.RegisterUser

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Mobile Layout -->
      <div class="md:hidden min-h-screen bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400 flex items-center justify-center p-6">
        <div class="w-full max-w-sm">
          <!-- Logo Section -->
          <div class="text-center mb-8">
            <div class="inline-flex items-center justify-center w-20 h-20 bg-white rounded-full shadow-lg mb-4 animate-bounce">
              <div class="w-12 h-12 bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 rounded-lg flex items-center justify-center">
                <span class="text-white font-bold text-xl">PY</span>
              </div>
            </div>
            <h1 class="text-3xl font-bold text-white mb-2">Join Prime Youth</h1>
            <p class="text-white/80">Start your family's adventure</p>
          </div>
          
    <!-- Signup Form -->
          <div class="bg-white/25 backdrop-blur-lg border border-white/[0.18] rounded-2xl p-6">
            <.form
              :let={f}
              for={@form}
              id="registration_form_mobile"
              phx-submit="save"
              phx-change="validate"
              class="space-y-4"
            >
              <!-- Error Messages -->
              <%= if @form.errors != [] do %>
                <div class="bg-red-500/20 border border-red-500/30 text-white rounded-xl p-3 text-sm">
                  <p class="font-semibold mb-1">Please fix the following errors:</p>
                  <ul class="list-disc list-inside space-y-1">
                    <%= for {field, {message, _}} <- @form.errors do %>
                      <li>{Phoenix.Naming.humanize(field)}: {message}</li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
              
    <!-- Name Fields -->
              <div class="grid grid-cols-2 gap-3">
                <div class="space-y-1">
                  <label for="mobile-first-name" class="block text-sm font-medium text-white">
                    First Name
                  </label>
                  <input
                    type="text"
                    id="mobile-first-name"
                    name={f[:first_name].name}
                    value={Phoenix.HTML.Form.normalize_value("text", f[:first_name].value)}
                    placeholder="First"
                    required
                    autocomplete="given-name"
                    class="w-full px-3 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
                  />
                </div>
                <div class="space-y-1">
                  <label for="mobile-last-name" class="block text-sm font-medium text-white">
                    Last Name
                  </label>
                  <input
                    type="text"
                    id="mobile-last-name"
                    name={f[:last_name].name}
                    value={Phoenix.HTML.Form.normalize_value("text", f[:last_name].value)}
                    placeholder="Last"
                    required
                    autocomplete="family-name"
                    class="w-full px-3 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
                  />
                </div>
              </div>
              
    <!-- Email Field -->
              <div class="space-y-1">
                <label for="mobile-email" class="block text-sm font-medium text-white">Email</label>
                <input
                  type="email"
                  id="mobile-email"
                  name={f[:email].name}
                  value={Phoenix.HTML.Form.normalize_value("email", f[:email].value)}
                  placeholder="your@email.com"
                  required
                  autocomplete="email"
                  class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
                />
              </div>
              
    <!-- Password Fields -->
              <div class="space-y-1">
                <label for="mobile-password" class="block text-sm font-medium text-white">
                  Password
                </label>
                <input
                  type="password"
                  id="mobile-password"
                  name={f[:password].name}
                  placeholder="Create password"
                  required
                  autocomplete="new-password"
                  class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
                />
              </div>
              
    <!-- Signup Button -->
              <button
                type="submit"
                class="w-full bg-white text-gray-900 py-3 px-4 rounded-xl font-semibold hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-white/50 transform hover:scale-105 transition-all duration-200 shadow-lg"
              >
                Create Account
              </button>
              
    <!-- Login Link -->
              <div class="text-center">
                <p class="text-white/80 text-sm">
                  Already have an account?
                  <.link
                    navigate={~p"/users/log-in"}
                    class="text-white font-medium hover:text-white/80 transition-colors ml-1"
                  >
                    Log in
                  </.link>
                </p>
              </div>
            </.form>
          </div>
        </div>
      </div>
      
    <!-- Desktop/Tablet Layout -->
      <div class="hidden md:grid md:grid-cols-2 min-h-screen">
        <!-- Left Side - Branding -->
        <div class="bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400 flex items-center justify-center p-8">
          <div class="text-center text-white max-w-md">
            <div class="inline-flex items-center justify-center w-24 h-24 bg-white/20 backdrop-blur-sm rounded-full shadow-xl mb-6">
              <div class="w-16 h-16 bg-white rounded-xl flex items-center justify-center">
                <span class="text-2xl font-bold bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 bg-clip-text text-transparent">
                  PY
                </span>
              </div>
            </div>
            <h1 class="text-4xl font-bold mb-4">Join Prime Youth</h1>
            <p class="text-xl text-white/90 mb-8">Start Your Family's Adventure</p>
            <div class="space-y-4 text-white/80">
              <div class="flex items-center justify-center space-x-3">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"
                  >
                  </path>
                </svg>
                <span>Join thousands of happy families</span>
              </div>
              <div class="flex items-center justify-center space-x-3">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  >
                  </path>
                </svg>
                <span>Quick and easy enrollment process</span>
              </div>
              <div class="flex items-center justify-center space-x-3">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
                  >
                  </path>
                </svg>
                <span>Safe, secure, and trusted platform</span>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Right Side - Signup Form -->
        <div class="bg-white flex items-center justify-center p-8 lg:p-12">
          <div class="w-full max-w-md">
            <div class="text-center mb-8">
              <h2 class="text-3xl font-bold text-gray-900 mb-2">Create Account</h2>
              <p class="text-gray-600">Join Prime Youth and start your family's adventure</p>
            </div>

            <.form
              :let={f}
              for={@form}
              id="registration_form_desktop"
              phx-submit="save"
              phx-change="validate"
              class="space-y-4"
            >
              <!-- Error Messages -->
              <%= if @form.errors != [] do %>
                <div class="bg-red-50 border border-red-200 text-red-800 rounded-xl p-4 text-sm">
                  <p class="font-semibold mb-2">Please fix the following errors:</p>
                  <ul class="list-disc list-inside space-y-1">
                    <%= for {field, {message, _}} <- @form.errors do %>
                      <li>{Phoenix.Naming.humanize(field)}: {message}</li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
              
    <!-- Name Fields -->
              <div class="grid grid-cols-2 gap-4">
                <div class="space-y-1">
                  <label for="desktop-first-name" class="block text-sm font-medium text-gray-700">
                    First Name
                  </label>
                  <input
                    type="text"
                    id="desktop-first-name"
                    name={f[:first_name].name}
                    value={Phoenix.HTML.Form.normalize_value("text", f[:first_name].value)}
                    placeholder="First name"
                    required
                    autocomplete="given-name"
                    class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
                  />
                </div>
                <div class="space-y-1">
                  <label for="desktop-last-name" class="block text-sm font-medium text-gray-700">
                    Last Name
                  </label>
                  <input
                    type="text"
                    id="desktop-last-name"
                    name={f[:last_name].name}
                    value={Phoenix.HTML.Form.normalize_value("text", f[:last_name].value)}
                    placeholder="Last name"
                    required
                    autocomplete="family-name"
                    class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
                  />
                </div>
              </div>
              
    <!-- Email Field -->
              <div class="space-y-1">
                <label for="desktop-email" class="block text-sm font-medium text-gray-700">
                  Email
                </label>
                <input
                  type="email"
                  id="desktop-email"
                  name={f[:email].name}
                  value={Phoenix.HTML.Form.normalize_value("email", f[:email].value)}
                  placeholder="your@email.com"
                  required
                  autocomplete="email"
                  class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
                />
              </div>
              
    <!-- Password Field -->
              <div class="space-y-1">
                <label for="desktop-password" class="block text-sm font-medium text-gray-700">
                  Password
                </label>
                <input
                  type="password"
                  id="desktop-password"
                  name={f[:password].name}
                  placeholder="Create a password (at least 12 characters)"
                  required
                  autocomplete="new-password"
                  class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
                />
              </div>
              
    <!-- Signup Button -->
              <button
                type="submit"
                class="w-full bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white py-3 px-4 rounded-xl font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200"
              >
                Create Account
              </button>
              
    <!-- Login Link -->
              <div class="text-center">
                <p class="text-gray-600 text-sm">
                  Already have an account?
                  <.link
                    navigate={~p"/users/log-in"}
                    class="text-prime-cyan-400 font-medium hover:text-prime-cyan-400/80 transition-colors ml-1"
                  >
                    Log in
                  </.link>
                </p>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: PrimeYouthWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = User.registration_changeset(%User{}, %{})
    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case RegisterUser.execute(%{
           email: user_params["email"],
           first_name: user_params["first_name"],
           last_name: user_params["last_name"],
           password: user_params["password"]
         }) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Account created successfully! Please check #{user.email} to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, :email_taken} ->
        changeset =
          %User{}
          |> User.registration_changeset(user_params)
          |> Ecto.Changeset.add_error(:email, "has already been taken")
          |> Map.put(:action, :validate)

        {:noreply, assign_form(socket, changeset)}

      {:error, :email_required} ->
        changeset =
          %User{}
          |> User.registration_changeset(user_params)
          |> Ecto.Changeset.add_error(:email, "can't be blank")
          |> Map.put(:action, :validate)

        {:noreply, assign_form(socket, changeset)}

      {:error, :first_name_required} ->
        changeset =
          %User{}
          |> User.registration_changeset(user_params)
          |> Ecto.Changeset.add_error(:first_name, "can't be blank")
          |> Map.put(:action, :validate)

        {:noreply, assign_form(socket, changeset)}

      {:error, :last_name_required} ->
        changeset =
          %User{}
          |> User.registration_changeset(user_params)
          |> Ecto.Changeset.add_error(:last_name, "can't be blank")
          |> Map.put(:action, :validate)

        {:noreply, assign_form(socket, changeset)}

      {:error, _reason} ->
        changeset =
          %User{}
          |> User.registration_changeset(user_params)
          |> Ecto.Changeset.add_error(:email, "registration failed")
          |> Map.put(:action, :validate)

        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> User.registration_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
