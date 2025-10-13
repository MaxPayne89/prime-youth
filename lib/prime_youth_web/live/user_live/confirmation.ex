defmodule PrimeYouthWeb.UserLive.Confirmation do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Auth.Queries

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
    <div class="min-h-screen bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400 flex items-center justify-center p-6">
      <div class="w-full max-w-md">
        <!-- Logo Section -->
        <div class="text-center mb-8">
          <div class="inline-flex items-center justify-center w-20 h-20 bg-white rounded-full shadow-lg mb-4">
            <div class="w-12 h-12 bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 rounded-lg flex items-center justify-center">
              <span class="text-white font-bold text-xl">PY</span>
            </div>
          </div>
          <h1 class="text-3xl font-bold text-white mb-2">Welcome!</h1>
          <p class="text-white/80">{@user.email}</p>
        </div>
        
    <!-- Confirmation Form -->
        <div class="bg-white/25 backdrop-blur-lg border border-white/[0.18] rounded-2xl p-6">
          <.form
            :let={f}
            :if={!@user.confirmed_at}
            for={@form}
            id="confirmation_form"
            phx-mounted={JS.focus_first()}
            phx-submit="submit"
            action={~p"/users/log-in?_action=confirmed"}
            phx-trigger-action={@trigger_submit}
            class="space-y-4"
          >
            <input
              type="hidden"
              name={f[:token].name}
              value={Phoenix.HTML.Form.normalize_value("hidden", f[:token].value)}
            />

            <div class="text-center mb-4">
              <p class="text-white text-sm mb-2">
                Click below to confirm your account and log in
              </p>
            </div>

            <button
              type="submit"
              name={f[:remember_me].name}
              value="true"
              phx-disable-with="Confirming..."
              class="w-full bg-white text-gray-900 py-3 px-4 rounded-xl font-semibold hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-white/50 transform hover:scale-105 transition-all duration-200 shadow-lg"
            >
              Confirm and stay logged in
            </button>

            <button
              type="submit"
              phx-disable-with="Confirming..."
              class="w-full bg-white/20 text-white py-3 px-4 rounded-xl font-semibold border border-white/30 hover:bg-white/30 focus:outline-none focus:ring-2 focus:ring-white/50 transition-all duration-200"
            >
              Confirm and log in only this time
            </button>
          </.form>

          <.form
            :let={f}
            :if={@user.confirmed_at}
            for={@form}
            id="login_form"
            phx-submit="submit"
            phx-mounted={JS.focus_first()}
            action={~p"/users/log-in"}
            phx-trigger-action={@trigger_submit}
            class="space-y-4"
          >
            <input
              type="hidden"
              name={f[:token].name}
              value={Phoenix.HTML.Form.normalize_value("hidden", f[:token].value)}
            />

            <div class="text-center mb-4">
              <p class="text-white text-sm mb-2">
                Your account is already confirmed. Click below to log in.
              </p>
            </div>

            <%= if @current_scope do %>
              <button
                type="submit"
                phx-disable-with="Logging in..."
                class="w-full bg-white text-gray-900 py-3 px-4 rounded-xl font-semibold hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-white/50 transform hover:scale-105 transition-all duration-200 shadow-lg"
              >
                Log in
              </button>
            <% else %>
              <button
                type="submit"
                name={f[:remember_me].name}
                value="true"
                phx-disable-with="Logging in..."
                class="w-full bg-white text-gray-900 py-3 px-4 rounded-xl font-semibold hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-white/50 transform hover:scale-105 transition-all duration-200 shadow-lg"
              >
                Keep me logged in on this device
              </button>

              <button
                type="submit"
                phx-disable-with="Logging in..."
                class="w-full bg-white/20 text-white py-3 px-4 rounded-xl font-semibold border border-white/30 hover:bg-white/30 focus:outline-none focus:ring-2 focus:ring-white/50 transition-all duration-200"
              >
                Log me in only this time
              </button>
            <% end %>
          </.form>

          <p
            :if={!@user.confirmed_at}
            class="text-white/70 text-xs text-center mt-6 p-3 bg-white/10 rounded-xl"
          >
            💡 Tip: If you prefer passwords, you can enable them in the user settings.
          </p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Queries.get_user_by_magic_link_token(token) do
      {:ok, user} ->
        form = to_form(%{"token" => token}, as: "user")

        {:ok, assign(socket, user: user, form: form, trigger_submit: false),
         temporary_assigns: [form: nil]}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "The link is invalid or it has expired.")
         |> redirect(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
