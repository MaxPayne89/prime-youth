defmodule PrimeYouthWeb.UserLive.Settings do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Accounts

  on_mount {PrimeYouthWeb.UserAuth, :require_sudo_mode}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          {gettext("Account Settings")}
          <:subtitle>{gettext("Manage your account email address and password settings")}</:subtitle>
        </.header>
      </div>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label={gettext("Email")}
          autocomplete="username"
          required
        />
        <.button phx-disable-with={gettext("Changing...")}>{gettext("Change Email")}</.button>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/users/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_user_email"
          autocomplete="username"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label={gettext("New password")}
          autocomplete="new-password"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label={gettext("Confirm new password")}
          autocomplete="new-password"
        />
        <.button phx-disable-with={gettext("Saving...")}>
          {gettext("Save Password")}
        </.button>
      </.form>

      <div class="divider" />

      <div class="text-center">
        <.header>
          {gettext("Language Preference")}
          <:subtitle>{gettext("Choose your preferred language for the interface")}</:subtitle>
        </.header>

        <.form for={@locale_form} id="locale_form" phx-change="update_locale">
          <div class="flex justify-center gap-4">
            <label class={[
              "flex items-center gap-2 px-4 py-3 rounded-lg border-2 cursor-pointer transition-all",
              if(@current_scope.user.locale == "en",
                do: "border-teal-500 bg-teal-50",
                else: "border-gray-200 hover:border-gray-300"
              )
            ]}>
              <input
                type="radio"
                name="user[locale]"
                value="en"
                checked={@current_scope.user.locale == "en"}
                class="hidden"
              />
              <span class="text-2xl">🇬🇧</span>
              <span class="font-medium">{gettext("English")}</span>
            </label>

            <label class={[
              "flex items-center gap-2 px-4 py-3 rounded-lg border-2 cursor-pointer transition-all",
              if(@current_scope.user.locale == "de",
                do: "border-teal-500 bg-teal-50",
                else: "border-gray-200 hover:border-gray-300"
              )
            ]}>
              <input
                type="radio"
                name="user[locale]"
                value="de"
                checked={@current_scope.user.locale == "de"}
                class="hidden"
              />
              <span class="text-2xl">🇩🇪</span>
              <span class="font-medium">{gettext("Deutsch")}</span>
            </label>
          </div>
        </.form>
      </div>

      <div class="divider" />

      <div class="text-center">
        <.header>
          {gettext("Your Data")}
          <:subtitle>{gettext("Download a copy of all your personal data")}</:subtitle>
        </.header>

        <.link
          href={~p"/users/export-data"}
          class="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          <.icon name="hero-arrow-down-tray" class="w-5 h-5" /> {gettext("Download My Data")}
        </.link>
      </div>

      <div class="divider" />

      <div class="text-center">
        <.header>
          {gettext("Delete Account")}
          <:subtitle>{gettext("Permanently delete your account and all associated data")}</:subtitle>
        </.header>

        <.form for={@delete_form} id="delete_account_form" phx-submit="delete_account">
          <p class="text-sm text-gray-600 mb-4">
            {gettext(
              "This action cannot be undone. Your account data will be anonymized and you will be logged out."
            )}
          </p>
          <.input
            field={@delete_form[:password]}
            type="password"
            label={gettext("Enter your password to confirm")}
            autocomplete="current-password"
            required
          />
          <.button
            type="submit"
            class="bg-red-600 hover:bg-red-700"
            phx-disable-with={gettext("Deleting...")}
          >
            {gettext("Delete My Account")}
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, gettext("Email changed successfully."))

        {:error, _} ->
          put_flash(socket, :error, gettext("Email change link is invalid or it has expired."))
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)
    locale_changeset = Accounts.change_user_locale(user, %{})

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:locale_form, to_form(locale_changeset))
      |> assign(:delete_form, to_form(%{"password" => ""}, as: :delete))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = gettext("A link to confirm your email change has been sent to the new address.")
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("update_locale", %{"user" => %{"locale" => locale}}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.update_user_locale(user, %{locale: locale}) do
      {:ok, updated_user} ->
        Gettext.put_locale(PrimeYouthWeb.Gettext, locale)

        {:noreply,
         socket
         |> assign(:current_scope, %{socket.assigns.current_scope | user: updated_user})
         |> assign(:locale, locale)
         |> put_flash(:info, gettext("Language preference updated successfully."))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update language preference."))}
    end
  end

  def handle_event("delete_account", %{"delete" => %{"password" => password}}, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.get_user_by_email_and_password(user.email, password) do
      %{} = _verified_user ->
        case Accounts.anonymize_user(user) do
          {:ok, _anonymized_user} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Your account has been deleted."))
             |> redirect(to: ~p"/")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, gettext("Failed to delete account. Please try again."))
             |> assign(:delete_form, to_form(%{"password" => ""}, as: :delete))}
        end

      nil ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Invalid password."))
         |> assign(:delete_form, to_form(%{"password" => ""}, as: :delete))}
    end
  end
end
