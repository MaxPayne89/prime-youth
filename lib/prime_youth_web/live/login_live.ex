defmodule PrimeYouthWeb.LoginLive do
  use PrimeYouthWeb, :live_view
  import PrimeYouthWeb.UIComponents

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Sign In")
      |> assign(email: "")
      |> assign(password: "")
      |> assign(remember_me: false)
      |> assign(errors: [])

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"login" => params}, socket) do
    socket =
      socket
      |> assign(email: Map.get(params, "email", ""))
      |> assign(password: Map.get(params, "password", ""))
      |> assign(remember_me: Map.get(params, "remember_me", "false") == "true")

    {:noreply, socket}
  end

  @impl true
  def handle_event("login", %{"login" => params}, socket) do
    email = Map.get(params, "email", "")
    password = Map.get(params, "password", "")

    # TODO: Implement actual authentication
    # For now, accept any email/password combination
    if email != "" and password != "" do
      {:noreply, push_navigate(socket, to: ~p"/")}
    else
      {:noreply, assign(socket, errors: ["Please enter both email and password"])}
    end
  end

  @impl true
  def handle_event("social_login", %{"provider" => _provider}, socket) do
    # TODO: Implement social login
    {:noreply, socket}
  end

  @impl true
  def handle_event("forgot_password", _params, socket) do
    # TODO: Implement forgot password functionality
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
            <h1 class="text-3xl font-bold text-white mb-2">Prime Youth</h1>
            <p class="text-white/80">Afterschool Adventures Await</p>
          </div>
          
    <!-- Login Form -->
          <div class="bg-white/25 backdrop-blur-lg border border-white/[0.18] rounded-2xl p-6">
            <form phx-submit="login" phx-change="validate" class="space-y-6">
              <!-- Email Field -->
              <div class="space-y-2">
                <label for="mobile-email" class="block text-sm font-medium text-white">Email</label>
                <div class="relative">
                  <input
                    type="email"
                    id="mobile-email"
                    name="login[email]"
                    placeholder="your@email.com"
                    value={@email}
                    required
                    autocomplete="email"
                    class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
                  />
                  <div class="absolute inset-y-0 right-0 flex items-center pr-3">
                    <.email_icon color="text-white/60" />
                  </div>
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
                    name="login[password]"
                    placeholder="Enter your password"
                    value={@password}
                    required
                    autocomplete="current-password"
                    class="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50 focus:border-transparent transition-all"
                  />
                  <div class="absolute inset-y-0 right-0 flex items-center pr-3">
                    <.password_icon color="text-white/60" />
                  </div>
                </div>
              </div>
              
    <!-- Remember Me & Forgot Password -->
              <div class="flex items-center justify-between text-sm">
                <label class="flex items-center text-white cursor-pointer">
                  <input
                    type="checkbox"
                    name="login[remember_me]"
                    checked={@remember_me}
                    class="w-4 h-4 text-white bg-white/10 border-white/20 rounded focus:ring-white/50 focus:ring-offset-0"
                  />
                  <span class="ml-2">Remember me</span>
                </label>
                <button
                  type="button"
                  phx-click="forgot_password"
                  class="text-white hover:text-white/80 transition-colors"
                >
                  Forgot password?
                </button>
              </div>
              
    <!-- Login Button -->
              <button
                type="submit"
                class="w-full bg-white text-gray-900 py-3 px-4 rounded-xl font-semibold hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-white/50 transform hover:scale-105 transition-all duration-200 shadow-lg"
              >
                Sign In
              </button>
              
    <!-- Social Login -->
              <.section_divider
                text="Or continue with"
                bg_color="bg-transparent"
                text_color="text-white/80"
                line_color="border-white/20"
              />

              <div class="grid grid-cols-2 gap-3">
                <.social_button
                  provider="google"
                  variant="dark"
                  phx-click="social_login"
                  phx-value-provider="google"
                  class="py-2"
                />
                <.social_button
                  provider="facebook"
                  variant="dark"
                  phx-click="social_login"
                  phx-value-provider="facebook"
                  class="py-2"
                />
              </div>
              
    <!-- Sign Up Link -->
              <div class="text-center">
                <p class="text-white/80 text-sm">
                  Don't have an account?
                  <.link
                    navigate={~p"/signup"}
                    class="text-white font-medium hover:text-white/80 transition-colors ml-1"
                  >
                    Sign up
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
          <div class="w-full max-w-md">
            <div class="text-center mb-8">
              <h2 class="text-3xl font-bold text-gray-900 mb-2">Welcome Back</h2>
              <p class="text-gray-600">Sign in to manage your children's activities</p>
            </div>
            
    <!-- Error Messages -->
            <.error_alert errors={@errors} />

            <form phx-submit="login" phx-change="validate" class="space-y-6">
              <!-- Email Field -->
              <div class="space-y-2">
                <label for="desktop-email" class="block text-sm font-medium text-gray-700">
                  Email
                </label>
                <div class="relative">
                  <input
                    type="email"
                    id="desktop-email"
                    name="login[email]"
                    placeholder="your@email.com"
                    value={@email}
                    required
                    autocomplete="email"
                    class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
                  />
                  <div class="absolute inset-y-0 right-0 flex items-center pr-3">
                    <.email_icon />
                  </div>
                </div>
              </div>
              
    <!-- Password Field -->
              <div class="space-y-2">
                <label for="desktop-password" class="block text-sm font-medium text-gray-700">
                  Password
                </label>
                <div class="relative">
                  <input
                    type="password"
                    id="desktop-password"
                    name="login[password]"
                    placeholder="Enter your password"
                    value={@password}
                    required
                    autocomplete="current-password"
                    class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
                  />
                  <div class="absolute inset-y-0 right-0 flex items-center pr-3">
                    <.password_icon />
                  </div>
                </div>
              </div>
              
    <!-- Remember Me & Forgot Password -->
              <div class="flex items-center justify-between text-sm">
                <label class="flex items-center text-gray-700 cursor-pointer">
                  <input
                    type="checkbox"
                    name="login[remember_me]"
                    checked={@remember_me}
                    class="w-4 h-4 text-prime-cyan-400 bg-gray-100 border-gray-300 rounded focus:ring-prime-cyan-400 focus:ring-2"
                  />
                  <span class="ml-2">Remember me</span>
                </label>
                <button
                  type="button"
                  phx-click="forgot_password"
                  class="text-prime-cyan-400 hover:text-prime-cyan-400/80 transition-colors font-medium"
                >
                  Forgot password?
                </button>
              </div>
              
    <!-- Login Button -->
              <button
                type="submit"
                class="w-full bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white py-3 px-4 rounded-xl font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200"
              >
                Sign In
              </button>
              
    <!-- Social Login -->
              <.section_divider text="Or continue with" />

              <div class="grid grid-cols-2 gap-3">
                <.social_button
                  provider="google"
                  variant="light"
                  phx-click="social_login"
                  phx-value-provider="google"
                />
                <.social_button
                  provider="facebook"
                  variant="light"
                  phx-click="social_login"
                  phx-value-provider="facebook"
                />
              </div>
              
    <!-- Sign Up Link -->
              <div class="text-center">
                <p class="text-gray-600 text-sm">
                  Don't have an account?
                  <.link
                    navigate={~p"/signup"}
                    class="text-prime-cyan-400 font-medium hover:text-prime-cyan-400/80 transition-colors ml-1"
                  >
                    Sign up
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
end
