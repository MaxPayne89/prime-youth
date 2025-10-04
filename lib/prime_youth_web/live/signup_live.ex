defmodule PrimeYouthWeb.SignupLive do
  use PrimeYouthWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Sign Up")
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
              <div class="relative">
                <div class="absolute inset-0 flex items-center">
                  <div class="w-full border-t border-white/20"></div>
                </div>
                <div class="relative flex justify-center text-sm">
                  <span class="px-2 bg-transparent text-white/80">Or sign up with</span>
                </div>
              </div>

              <div class="grid grid-cols-2 gap-3">
                <button
                  type="button"
                  phx-click="social_signup"
                  phx-value-provider="google"
                  class="flex justify-center items-center px-4 py-2 bg-white/10 border border-white/20 rounded-lg text-white hover:bg-white/20 transition-all"
                >
                  <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
                    <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
                    <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
                    <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
                  </svg>
                </button>
                <button
                  type="button"
                  phx-click="social_signup"
                  phx-value-provider="facebook"
                  class="flex justify-center items-center px-4 py-2 bg-white/10 border border-white/20 rounded-lg text-white hover:bg-white/20 transition-all"
                >
                  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
                  </svg>
                </button>
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
            <div :if={@errors != []} class="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
              <div class="flex">
                <svg
                  class="w-5 h-5 text-red-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  >
                  </path>
                </svg>
                <div class="ml-3">
                  <p :for={error <- @errors} class="text-sm text-red-700">{error}</p>
                </div>
              </div>
            </div>

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
              <div class="relative">
                <div class="absolute inset-0 flex items-center">
                  <div class="w-full border-t border-gray-200"></div>
                </div>
                <div class="relative flex justify-center text-sm">
                  <span class="px-2 bg-white text-gray-500">Or sign up with</span>
                </div>
              </div>

              <div class="grid grid-cols-2 gap-3">
                <button
                  type="button"
                  phx-click="social_signup"
                  phx-value-provider="google"
                  class="flex justify-center items-center px-4 py-3 border border-gray-300 rounded-xl text-gray-700 hover:bg-gray-50 transition-all"
                >
                  <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
                    <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
                    <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
                    <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
                  </svg>
                </button>
                <button
                  type="button"
                  phx-click="social_signup"
                  phx-value-provider="facebook"
                  class="flex justify-center items-center px-4 py-3 border border-gray-300 rounded-xl text-gray-700 hover:bg-gray-50 transition-all"
                >
                  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
                  </svg>
                </button>
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
      if password != password_confirmation do
        ["Passwords do not match" | errors]
      else
        errors
      end

    errors =
      if not agree_terms do
        ["You must agree to the Terms of Service and Privacy Policy" | errors]
      else
        errors
      end

    Enum.reverse(errors)
  end
end
