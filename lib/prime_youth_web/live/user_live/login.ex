defmodule PrimeYouthWeb.UserLive.Login do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Auth.Application.UseCases.SendMagicLink

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
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
            <h1 class="text-3xl font-bold text-white mb-2">Prime Youth</h1>
            <p class="text-white/80">Afterschool Adventures Await</p>
          </div>
          
    <!-- Login Form -->
          <div
            id="mobile-login-container"
            class="bg-white/25 backdrop-blur-lg border border-white/[0.18] rounded-2xl p-6"
          >
            <%= if !is_nil(@current_scope.user) do %>
              <!-- Reauthentication Notice -->
              <div class="mb-6 p-4 bg-white/20 border border-white/30 rounded-xl">
                <p class="text-white text-sm font-medium">
                  You need to reauthenticate to continue.
                </p>
              </div>
            <% end %>

            <%= if @show_magic_link do %>
              <!-- Magic Link Form -->
              <.form
                :let={f}
                for={@form}
                id="login_form_magic_mobile"
                phx-submit="submit_magic"
                class="space-y-6"
              >
                <div class="space-y-2">
                  <label for="mobile-magic-email" class="block text-sm font-medium text-white">
                    Email
                  </label>
                  <div class="relative">
                    <input
                      type="email"
                      id="mobile-magic-email"
                      name={f[:email].name}
                      value={Phoenix.HTML.Form.normalize_value("email", f[:email].value)}
                      placeholder="your@email.com"
                      required
                      autocomplete="email"
                      class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  class="w-full bg-white text-gray-900 py-3 px-4 rounded-xl font-semibold hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-white/50 transform hover:scale-105 transition-all duration-200 shadow-lg"
                >
                  Send Magic Link
                </button>

                <button
                  type="button"
                  phx-click="toggle_form"
                  data-test-id="mobile-toggle-password"
                  class="w-full text-white/80 text-sm underline hover:text-white transition-colors"
                >
                  Or use password
                </button>
              </.form>
            <% else %>
              <!-- Password Form -->
              <.form
                :let={f}
                for={@form}
                id="login_form_password_mobile"
                action={~p"/users/log-in"}
                phx-submit="submit_password"
                phx-trigger-action={@trigger_submit}
                class="space-y-6"
              >
                <!-- Email Field -->
                <div class="space-y-2">
                  <label for="mobile-email" class="block text-sm font-medium text-white">Email</label>
                  <div class="relative">
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
                </div>
                
    <!-- Password Field -->
                <div class="space-y-2">
                  <label for="mobile-password" class="block text-sm font-medium text-white">
                    Password
                  </label>
                  <div class="relative">
                    <input
                      type="password"
                      id="mobile-password"
                      name={f[:password].name}
                      placeholder="Enter your password"
                      required
                      autocomplete="current-password"
                      class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
                    />
                  </div>
                </div>
                
    <!-- Remember Me -->
                <div class="flex items-center justify-between text-sm">
                  <label class="flex items-center text-white cursor-pointer">
                    <input
                      type="checkbox"
                      name={f[:remember_me].name}
                      value="true"
                      class="w-4 h-4 text-white bg-white/10 border-white/20 rounded focus:ring-white/50 focus:ring-offset-0"
                    />
                    <span class="ml-2">Remember me</span>
                  </label>
                  <button
                    type="button"
                    phx-click="toggle_form"
                    class="text-white hover:text-white/80 transition-colors"
                  >
                    Use magic link
                  </button>
                </div>
                
    <!-- Login Button -->
                <button
                  type="submit"
                  class="w-full bg-white text-gray-900 py-3 px-4 rounded-xl font-semibold hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-white/50 transform hover:scale-105 transition-all duration-200 shadow-lg"
                >
                  Sign In
                </button>
              </.form>
            <% end %>
            
    <!-- Sign Up Link -->
            <%= if is_nil(@current_scope.user) do %>
              <div class="text-center mt-6">
                <p class="text-white/80 text-sm">
                  Don't have an account?
                  <.link
                    navigate={~p"/users/register"}
                    class="text-white font-medium hover:text-white/80 transition-colors ml-1"
                    data-test-id="mobile-signup-link"
                  >
                    Sign up
                  </.link>
                </p>
              </div>
            <% end %>
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
            <h1 class="text-4xl font-bold mb-4">Prime Youth</h1>
            <p class="text-xl text-white/90 mb-8">Where Adventures Begin</p>
            <div class="space-y-4 text-white/80">
              <div class="flex items-center justify-center space-x-3">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  >
                  </path>
                </svg>
                <span>Expert instructors and safe environment</span>
              </div>
              <div class="flex items-center justify-center space-x-3">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  >
                  </path>
                </svg>
                <span>Flexible scheduling for busy families</span>
              </div>
              <div class="flex items-center justify-center space-x-3">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  >
                  </path>
                </svg>
                <span>Track your child's progress online</span>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Right Side - Login Form -->
        <div class="bg-white flex items-center justify-center p-8 lg:p-12">
          <div id="desktop-login-container" class="w-full max-w-md">
            <div class="text-center mb-8">
              <h2 class="text-3xl font-bold text-gray-900 mb-2">Welcome Back</h2>
              <p class="text-gray-600">Sign in to manage your children's activities</p>
            </div>

            <%= if !is_nil(@current_scope.user) do %>
              <!-- Reauthentication Notice -->
              <div class="mb-6 p-4 bg-prime-cyan-50 border border-prime-cyan-200 rounded-xl">
                <p class="text-gray-900 text-sm font-medium">
                  You need to reauthenticate to continue.
                </p>
              </div>
            <% end %>

            <%= if @show_magic_link do %>
              <!-- Magic Link Form -->
              <.form
                :let={f}
                for={@form}
                id="login_form_magic_desktop"
                phx-submit="submit_magic"
                class="space-y-6"
              >
                <div class="space-y-2">
                  <label for="desktop-magic-email" class="block text-sm font-medium text-gray-700">
                    Email
                  </label>
                  <div class="relative">
                    <input
                      type="email"
                      id="desktop-magic-email"
                      name={f[:email].name}
                      value={Phoenix.HTML.Form.normalize_value("email", f[:email].value)}
                      placeholder="your@email.com"
                      required
                      autocomplete="email"
                      class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  class="w-full bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white py-3 px-4 rounded-xl font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200"
                >
                  Send Magic Link
                </button>

                <button
                  type="button"
                  phx-click="toggle_form"
                  data-test-id="desktop-toggle-password"
                  class="w-full text-prime-cyan-400 text-sm underline hover:text-prime-cyan-400/80 transition-colors"
                >
                  Or sign in with password
                </button>
              </.form>
            <% else %>
              <!-- Password Form -->
              <.form
                :let={f}
                for={@form}
                id="login_form_password_desktop"
                action={~p"/users/log-in"}
                phx-submit="submit_password"
                phx-trigger-action={@trigger_submit}
                class="space-y-6"
              >
                <!-- Email Field -->
                <div class="space-y-2">
                  <label for="desktop-email" class="block text-sm font-medium text-gray-700">
                    Email address
                  </label>
                  <div class="relative">
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
                </div>
                
    <!-- Password Field -->
                <div class="space-y-2">
                  <label for="desktop-password" class="block text-sm font-medium text-gray-700">
                    Your password
                  </label>
                  <div class="relative">
                    <input
                      type="password"
                      id="desktop-password"
                      name={f[:password].name}
                      placeholder="Enter your password"
                      required
                      autocomplete="current-password"
                      class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
                    />
                  </div>
                </div>
                
    <!-- Remember Me -->
                <div class="flex items-center justify-between text-sm">
                  <label class="flex items-center text-gray-700 cursor-pointer">
                    <input
                      type="checkbox"
                      name={f[:remember_me].name}
                      value="true"
                      class="w-4 h-4 text-prime-cyan-400 bg-gray-100 border-gray-300 rounded focus:ring-prime-cyan-400 focus:ring-2"
                    />
                    <span class="ml-2">Keep me logged in</span>
                  </label>
                  <button
                    type="button"
                    phx-click="toggle_form"
                    class="text-prime-cyan-400 hover:text-prime-cyan-400/80 transition-colors font-medium"
                  >
                    Use magic link
                  </button>
                </div>
                
    <!-- Login Button -->
                <button
                  type="submit"
                  class="w-full bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white py-3 px-4 rounded-xl font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200"
                >
                  Continue
                </button>
              </.form>
            <% end %>
            
    <!-- Sign Up Link -->
            <%= if is_nil(@current_scope.user) do %>
              <div class="text-center mt-6">
                <p class="text-gray-600 text-sm">
                  Don't have an account?
                  <.link
                    navigate={~p"/users/register"}
                    class="text-prime-cyan-400 font-medium hover:text-prime-cyan-400/80 transition-colors ml-1"
                    data-test-id="desktop-signup-link"
                  >
                    Sign up
                  </.link>
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        if Map.has_key?(socket.assigns, :current_scope) &&
             socket.assigns.current_scope &&
             socket.assigns.current_scope.user do
          socket.assigns.current_scope.user.email
        end

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false, show_magic_link: true)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    SendMagicLink.execute(email)

    info = "If your email is in our system, you will receive a magic link shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> assign(show_magic_link: false)}
  end

  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, show_magic_link: not socket.assigns.show_magic_link)}
  end
end
