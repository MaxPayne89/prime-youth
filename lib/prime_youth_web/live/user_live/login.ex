defmodule PrimeYouthWeb.UserLive.Login do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <h1 class="text-4xl font-bold text-zinc-900">Log in</h1>
          <h2 class="mt-2 text-2xl font-semibold text-zinc-700">Welcome Back</h2>
          <p class="mt-2 text-sm text-zinc-600">
            <%= if @current_scope do %>
              You need to reauthenticate to perform sensitive actions on your account.
            <% else %>
              Don't have an account? <.link
                navigate={~p"/users/register"}
                class="font-semibold text-brand hover:underline"
                phx-no-format
              >Register</.link> for an account now.
            <% end %>
          </p>
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <div :if={!@show_password_form}>
          <.form
            :let={f}
            for={@form}
            id="login_form_magic_mobile"
            action={~p"/users/log-in"}
            phx-submit="submit_magic"
          >
            <.input
              readonly={!!@current_scope}
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              required
              phx-mounted={JS.focus()}
            />
            <.button class="btn btn-primary w-full">
              Send Magic Link
            </.button>
          </.form>

          <button
            type="button"
            phx-click="toggle_form"
            class="btn btn-ghost w-full mt-4"
          >
            Or use password
          </button>
        </div>

        <div :if={@show_password_form}>
          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
          >
            <.input
              readonly={!!@current_scope}
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              required
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              autocomplete="current-password"
            />
            <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
              Log in and stay logged in <span aria-hidden="true">→</span>
            </.button>
            <.button class="btn btn-primary btn-soft w-full mt-2">
              Log in only this time
            </.button>
          </.form>

          <button
            type="button"
            phx-click="toggle_form"
            class="btn btn-ghost w-full mt-4"
          >
            Or use magic link
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false, show_password_form: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, :show_password_form, !socket.assigns.show_password_form)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:prime_youth, PrimeYouth.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
