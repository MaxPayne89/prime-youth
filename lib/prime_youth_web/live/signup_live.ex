defmodule PrimeYouthWeb.SignupLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.UIComponents

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Sign Up")
      |> assign(current_user: nil)
      |> assign(first_name: "")
      |> assign(last_name: "")
      |> assign(email: "")
      |> assign(password: "")
      |> assign(password_confirmation: "")
      |> assign(agree_terms: false)
      |> assign(errors: [])

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_auth", _params, socket) do
    new_user = if !socket.assigns.current_user, do: sample_user()
    {:noreply, assign(socket, current_user: new_user)}
  end

  @impl true
  def handle_event("validate", %{"signup" => params}, socket) do
    socket =
      socket
      |> assign(first_name: Map.get(params, "first_name", ""))
      |> assign(last_name: Map.get(params, "last_name", ""))
      |> assign(email: Map.get(params, "email", ""))
      |> assign(password: Map.get(params, "password", ""))
      |> assign(password_confirmation: Map.get(params, "password_confirmation", ""))
      |> assign(agree_terms: Map.get(params, "agree_terms", "false") == "true")

    {:noreply, socket}
  end

  @impl true
  def handle_event("signup", %{"signup" => params}, socket) do
    first_name = Map.get(params, "first_name", "")
    last_name = Map.get(params, "last_name", "")
    email = Map.get(params, "email", "")
    password = Map.get(params, "password", "")
    password_confirmation = Map.get(params, "password_confirmation", "")
    agree_terms = Map.get(params, "agree_terms", "false") == "true"

    errors =
      validate_signup_params(
        first_name,
        last_name,
        email,
        password,
        password_confirmation,
        agree_terms
      )

    if errors == [] do
      # TODO: Implement actual user registration
      {:noreply, push_navigate(socket, to: ~p"/")}
    else
      {:noreply, assign(socket, errors: errors)}
    end
  end

  @impl true
  def handle_event("social_signup", %{"provider" => _provider}, socket) do
    # TODO: Implement social signup
    {:noreply, socket}
  end

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
            <form phx-submit="signup" phx-change="validate" class="space-y-4">
              <!-- Name Fields -->
              <div class="grid grid-cols-2 gap-3">
                <div class="space-y-1">
                  <label for="mobile-first-name" class="block text-sm font-medium text-white">
                    First Name
                  </label>
                  <input
                    type="text"
                    id="mobile-first-name"
                    name="signup[first_name]"
                    placeholder="First"
                    value={@first_name}
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
                    name="signup[last_name]"
                    placeholder="Last"
                    value={@last_name}
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
                  name="signup[email]"
                  placeholder="your@email.com"
                  value={@email}
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
                  name="signup[password]"
                  placeholder="Create password"
                  value={@password}
                  required
                  autocomplete="new-password"
                  class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
                />
              </div>

              <div class="space-y-1">
                <label for="mobile-password-confirmation" class="block text-sm font-medium text-white">
                  Confirm Password
                </label>
                <input
                  type="password"
                  id="mobile-password-confirmation"
                  name="signup[password_confirmation]"
                  placeholder="Confirm password"
                  value={@password_confirmation}
                  required
                  autocomplete="new-password"
                  class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
                />
              </div>
              
    <!-- Terms Agreement -->
              <div class="flex items-start space-x-2 text-sm">
                <input
                  type="checkbox"
                  id="mobile-agree-terms"
                  name="signup[agree_terms]"
                  checked={@agree_terms}
                  required
                  class="w-4 h-4 text-white bg-white/10 border-white/20 rounded focus:ring-white/50 focus:ring-offset-0 mt-0.5"
                />
                <label for="mobile-agree-terms" class="text-white/90 cursor-pointer">
                  I agree to the
                  <span class="text-white font-medium underline">Terms of Service</span>
                  and <span class="text-white font-medium underline">Privacy Policy</span>
                </label>
              </div>
              
    <!-- Signup Button -->
              <button
                type="submit"
                class="w-full bg-white text-gray-900 py-3 px-4 rounded-xl font-semibold hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-white/50 transform hover:scale-105 transition-all duration-200 shadow-lg"
              >
                Create Account
              </button>
              
    <!-- Social Signup -->
              <.section_divider
                text="Or sign up with"
                bg_color="bg-transparent"
                text_color="text-white/80"
                line_color="border-white/20"
              />

              <div class="grid grid-cols-2 gap-3">
                <.social_button
                  provider="google"
                  variant="dark"
                  phx-click="social_signup"
                  phx-value-provider="google"
                  class="py-2"
                />
                <.social_button
                  provider="facebook"
                  variant="dark"
                  phx-click="social_signup"
                  phx-value-provider="facebook"
                  class="py-2"
                />
              </div>
              
    <!-- Login Link -->
              <div class="text-center">
                <p class="text-white/80 text-sm">
                  Already have an account?
                  <.link
                    navigate={~p"/login"}
                    class="text-white font-medium hover:text-white/80 transition-colors ml-1"
                  >
                    Sign in
                  </.link>
                </p>
              </div>
            </form>
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
            
    <!-- Error Messages -->
            <.error_alert errors={@errors} />

            <form phx-submit="signup" phx-change="validate" class="space-y-4">
              <!-- Name Fields -->
              <div class="grid grid-cols-2 gap-4">
                <div class="space-y-1">
                  <label for="desktop-first-name" class="block text-sm font-medium text-gray-700">
                    First Name
                  </label>
                  <input
                    type="text"
                    id="desktop-first-name"
                    name="signup[first_name]"
                    placeholder="First name"
                    value={@first_name}
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
                    name="signup[last_name]"
                    placeholder="Last name"
                    value={@last_name}
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
                  name="signup[email]"
                  placeholder="your@email.com"
                  value={@email}
                  required
                  autocomplete="email"
                  class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
                />
              </div>
              
    <!-- Password Fields -->
              <div class="space-y-1">
                <label for="desktop-password" class="block text-sm font-medium text-gray-700">
                  Password
                </label>
                <input
                  type="password"
                  id="desktop-password"
                  name="signup[password]"
                  placeholder="Create a password"
                  value={@password}
                  required
                  autocomplete="new-password"
                  class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
                />
              </div>

              <div class="space-y-1">
                <label
                  for="desktop-password-confirmation"
                  class="block text-sm font-medium text-gray-700"
                >
                  Confirm Password
                </label>
                <input
                  type="password"
                  id="desktop-password-confirmation"
                  name="signup[password_confirmation]"
                  placeholder="Confirm your password"
                  value={@password_confirmation}
                  required
                  autocomplete="new-password"
                  class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
                />
              </div>
              
    <!-- Terms Agreement -->
              <div class="flex items-start space-x-2 text-sm">
                <input
                  type="checkbox"
                  id="desktop-agree-terms"
                  name="signup[agree_terms]"
                  checked={@agree_terms}
                  required
                  class="w-4 h-4 text-prime-cyan-400 bg-gray-100 border-gray-300 rounded focus:ring-prime-cyan-400 focus:ring-2 mt-0.5"
                />
                <label for="desktop-agree-terms" class="text-gray-600 cursor-pointer">
                  I agree to the
                  <span class="text-prime-cyan-400 font-medium underline">Terms of Service</span>
                  and <span class="text-prime-cyan-400 font-medium underline">Privacy Policy</span>
                </label>
              </div>
              
    <!-- Signup Button -->
              <button
                type="submit"
                class="w-full bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white py-3 px-4 rounded-xl font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200"
              >
                Create Account
              </button>
              
    <!-- Social Signup -->
              <.section_divider text="Or sign up with" />

              <div class="grid grid-cols-2 gap-3">
                <.social_button
                  provider="google"
                  variant="light"
                  phx-click="social_signup"
                  phx-value-provider="google"
                />
                <.social_button
                  provider="facebook"
                  variant="light"
                  phx-click="social_signup"
                  phx-value-provider="facebook"
                />
              </div>
              
    <!-- Login Link -->
              <div class="text-center">
                <p class="text-gray-600 text-sm">
                  Already have an account?
                  <.link
                    navigate={~p"/login"}
                    class="text-prime-cyan-400 font-medium hover:text-prime-cyan-400/80 transition-colors ml-1"
                  >
                    Sign in
                  </.link>
                </p>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to validate signup parameters
  defp validate_signup_params(
         first_name,
         last_name,
         email,
         password,
         password_confirmation,
         agree_terms
       ) do
    errors = []

    errors =
      if first_name == "" or last_name == "" do
        ["Please enter both first and last name" | errors]
      else
        errors
      end

    errors =
      if email == "" do
        ["Please enter an email address" | errors]
      else
        errors
      end

    errors =
      if password == "" do
        ["Please enter a password" | errors]
      else
        errors
      end

    errors =
      if String.length(password) < 6 do
        ["Password must be at least 6 characters long" | errors]
      else
        errors
      end

    errors =
      if password == password_confirmation do
        errors
      else
        ["Passwords do not match" | errors]
      end

    errors =
      if agree_terms do
        errors
      else
        ["You must agree to the Terms of Service and Privacy Policy" | errors]
      end

    Enum.reverse(errors)
  end

  # Sample data
  defp sample_user do
    %{
      name: "Sarah Johnson",
      email: "sarah.johnson@example.com",
      avatar:
        "https://images.unsplash.com/photo-1494790108755-2616b612b388?w=64&h=64&fit=crop&crop=face"
    }
  end
end
