defmodule KlassHeroWeb.UserLive.Settings do
  use KlassHeroWeb, :live_view

  alias KlassHero.Accounts
  alias KlassHeroWeb.Theme

  on_mount {KlassHeroWeb.UserAuth, :require_sudo_mode}

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", Theme.bg(:muted)]}>
      <%!-- Page Header --%>
      <.page_header variant={:gradient} container_class="max-w-4xl mx-auto">
        <:title>{gettext("Account Settings")}</:title>
        <:subtitle>{gettext("Manage your account and preferences")}</:subtitle>
      </.page_header>

      <div class="max-w-4xl mx-auto p-4">
        <div class="lg:flex lg:gap-6">
          <%!-- Sidebar Navigation (Desktop) --%>
          <nav class="hidden lg:block lg:w-64 lg:flex-shrink-0">
            <div class={[
              Theme.bg(:surface),
              "shadow-sm border overflow-hidden sticky top-4",
              Theme.rounded(:xl),
              Theme.border_color(:light)
            ]}>
              <div class={["p-4 border-b", Theme.border_color(:light)]}>
                <h3 class={["font-semibold text-sm", Theme.text_color(:muted)]}>
                  {gettext("Quick Navigation")}
                </h3>
              </div>
              <div>
                <.settings_nav_item
                  icon="hero-user-circle"
                  icon_bg={Theme.bg(:primary_light)}
                  icon_color={Theme.text_color(:primary)}
                  title={gettext("Profile")}
                  href="#profile"
                />
                <.settings_nav_item
                  icon="hero-shield-check"
                  icon_bg={Theme.bg(:secondary_light)}
                  icon_color={Theme.text_color(:secondary)}
                  title={gettext("Account Security")}
                  href="#security"
                />
                <.settings_nav_item
                  icon="hero-globe-alt"
                  icon_bg={Theme.bg(:accent_light)}
                  icon_color={Theme.text_color(:accent)}
                  title={gettext("Preferences")}
                  href="#preferences"
                />
                <.settings_nav_item
                  icon="hero-document-text"
                  icon_bg="bg-purple-100"
                  icon_color="text-purple-600"
                  title={gettext("Data & Privacy")}
                  href="#data-privacy"
                />
              </div>
            </div>
          </nav>

          <%!-- Main Content --%>
          <div class="flex-1 space-y-6">
            <%!-- Profile Section --%>
            <div
              id="profile"
              class={[
                Theme.bg(:surface),
                "shadow-sm border overflow-hidden",
                Theme.rounded(:xl),
                Theme.border_color(:light)
              ]}
            >
              <div class="p-5 flex items-center gap-4">
                <div class={[
                  "w-16 h-16 rounded-full flex items-center justify-center text-xl font-semibold",
                  Theme.bg(:primary_light),
                  Theme.text_color(:primary)
                ]}>
                  {@user_initials}
                </div>
                <div>
                  <h2 class={["font-semibold text-lg", Theme.text_color(:heading)]}>
                    {@current_scope.user.email}
                  </h2>
                  <p class={["text-sm", Theme.text_color(:muted)]}>
                    {gettext("Member since")} {@member_since}
                  </p>
                </div>
              </div>
            </div>

            <%!-- Account Security Card --%>
            <div
              id="security"
              class={[
                Theme.bg(:surface),
                "shadow-sm border overflow-hidden",
                Theme.rounded(:xl),
                Theme.border_color(:light)
              ]}
            >
              <div class={["p-5 border-b", Theme.border_color(:light)]}>
                <div class="flex items-center gap-3">
                  <.gradient_icon
                    gradient_class={Theme.bg(:secondary_light)}
                    size="sm"
                    shape="circle"
                  >
                    <.icon
                      name="hero-shield-check"
                      class={"w-5 h-5 #{Theme.text_color(:secondary)}"}
                    />
                  </.gradient_icon>
                  <div>
                    <h2 class={["font-semibold", Theme.text_color(:heading)]}>
                      {gettext("Account Security")}
                    </h2>
                    <p class={["text-sm", Theme.text_color(:muted)]}>
                      {gettext("Manage your email and password")}
                    </p>
                  </div>
                </div>
              </div>
              <div class="p-5 space-y-6">
                <%!-- Email Form --%>
                <div>
                  <h3 class={["text-sm font-medium mb-3", Theme.text_color(:heading)]}>
                    {gettext("Email Address")}
                  </h3>
                  <.form
                    for={@email_form}
                    id="email_form"
                    phx-submit="update_email"
                    phx-change="validate_email"
                    class="max-w-md"
                  >
                    <.input
                      field={@email_form[:email]}
                      type="email"
                      label={gettext("Email")}
                      autocomplete="username"
                      required
                    />
                    <.button phx-disable-with={gettext("Changing...")}>
                      {gettext("Change Email")}
                    </.button>
                  </.form>
                </div>

                <div class={["border-t", Theme.border_color(:light)]} />

                <%!-- Password Form --%>
                <div>
                  <h3 class={["text-sm font-medium mb-3", Theme.text_color(:heading)]}>
                    {gettext("Password")}
                  </h3>
                  <.form
                    for={@password_form}
                    id="password_form"
                    action={~p"/users/update-password"}
                    method="post"
                    phx-change="validate_password"
                    phx-submit="update_password"
                    phx-trigger-action={@trigger_submit}
                    class="max-w-md"
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
                </div>
              </div>
            </div>

            <%!-- Preferences Card --%>
            <div
              id="preferences"
              class={[
                Theme.bg(:surface),
                "shadow-sm border overflow-hidden",
                Theme.rounded(:xl),
                Theme.border_color(:light)
              ]}
            >
              <div class={["p-5 border-b", Theme.border_color(:light)]}>
                <div class="flex items-center gap-3">
                  <.gradient_icon
                    gradient_class={Theme.bg(:accent_light)}
                    size="sm"
                    shape="circle"
                  >
                    <.icon
                      name="hero-globe-alt"
                      class={"w-5 h-5 #{Theme.text_color(:accent)}"}
                    />
                  </.gradient_icon>
                  <div>
                    <h2 class={["font-semibold", Theme.text_color(:heading)]}>
                      {gettext("Preferences")}
                    </h2>
                    <p class={["text-sm", Theme.text_color(:muted)]}>
                      {gettext("Customize your experience")}
                    </p>
                  </div>
                </div>
              </div>
              <div class="p-5">
                <h3 class={["text-sm font-medium mb-3", Theme.text_color(:heading)]}>
                  {gettext("Language Preference")}
                </h3>
                <p class={["text-sm mb-4", Theme.text_color(:muted)]}>
                  {gettext("Choose your preferred language for the interface")}
                </p>
                <.form for={@locale_form} id="locale_form" phx-change="update_locale">
                  <div class="flex flex-wrap gap-3">
                    <label class={[
                      "flex items-center gap-2 px-4 py-3 rounded-lg border-2 cursor-pointer",
                      Theme.transition(:normal),
                      if(@current_scope.user.locale == "en",
                        do: [Theme.border_color(:primary), Theme.bg(:primary_light)],
                        else: [Theme.border_color(:light), "hover:border-hero-grey-300"]
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
                      "flex items-center gap-2 px-4 py-3 rounded-lg border-2 cursor-pointer",
                      Theme.transition(:normal),
                      if(@current_scope.user.locale == "de",
                        do: [Theme.border_color(:primary), Theme.bg(:primary_light)],
                        else: [Theme.border_color(:light), "hover:border-hero-grey-300"]
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
            </div>

            <%!-- Data & Privacy Card --%>
            <div
              id="data-privacy"
              class={[
                Theme.bg(:surface),
                "shadow-sm border overflow-hidden",
                Theme.rounded(:xl),
                Theme.border_color(:light)
              ]}
            >
              <div class={["p-5 border-b", Theme.border_color(:light)]}>
                <div class="flex items-center gap-3">
                  <.gradient_icon gradient_class="bg-purple-100" size="sm" shape="circle">
                    <.icon name="hero-document-text" class="w-5 h-5 text-purple-600" />
                  </.gradient_icon>
                  <div>
                    <h2 class={["font-semibold", Theme.text_color(:heading)]}>
                      {gettext("Data & Privacy")}
                    </h2>
                    <p class={["text-sm", Theme.text_color(:muted)]}>
                      {gettext("Download your data or delete your account")}
                    </p>
                  </div>
                </div>
              </div>
              <div class="p-5 space-y-6">
                <%!-- Data Export --%>
                <div>
                  <h3 class={["text-sm font-medium mb-2", Theme.text_color(:heading)]}>
                    {gettext("Your Data")}
                  </h3>
                  <p class={["text-sm mb-4", Theme.text_color(:muted)]}>
                    {gettext("Download a copy of all your personal data")}
                  </p>
                  <.link
                    href={~p"/users/export-data"}
                    class={[
                      "inline-flex items-center gap-2 px-4 py-2 rounded-lg font-medium",
                      Theme.bg(:primary),
                      "text-white hover:opacity-90",
                      Theme.transition(:normal)
                    ]}
                  >
                    <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
                    {gettext("Download My Data")}
                  </.link>
                </div>

                <%!-- Danger Zone Divider --%>
                <div class="flex items-center gap-3">
                  <div class="flex-1 border-t border-red-200" />
                  <span class="text-xs font-medium text-red-500 uppercase tracking-wide">
                    {gettext("Danger Zone")}
                  </span>
                  <div class="flex-1 border-t border-red-200" />
                </div>

                <%!-- Delete Account --%>
                <div class="bg-red-50 rounded-lg p-4 border border-red-200">
                  <h3 class="text-sm font-medium mb-2 text-red-800">
                    {gettext("Delete Account")}
                  </h3>
                  <p class="text-sm text-red-600 mb-4">
                    {gettext(
                      "This action cannot be undone. Your account data will be anonymized and you will be logged out."
                    )}
                  </p>
                  <.form
                    for={@delete_form}
                    id="delete_account_form"
                    phx-submit="delete_account"
                    class="max-w-md"
                  >
                    <.input
                      field={@delete_form[:password]}
                      type="password"
                      label={gettext("Enter your password to confirm")}
                      autocomplete="current-password"
                      required
                    />
                    <.button
                      type="submit"
                      class="bg-red-600 hover:bg-red-700 border-red-600 hover:border-red-700"
                      phx-disable-with={gettext("Deleting...")}
                    >
                      {gettext("Delete My Account")}
                    </.button>
                  </.form>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper component for sidebar navigation
  defp settings_nav_item(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "flex items-center gap-3 p-3 hover:bg-hero-grey-50",
        Theme.transition(:normal)
      ]}
    >
      <div class={["w-8 h-8 rounded-full flex items-center justify-center", @icon_bg]}>
        <.icon name={@icon} class={"w-4 h-4 #{@icon_color}"} />
      </div>
      <span class={["text-sm font-medium", Theme.text_color(:body)]}>
        {@title}
      </span>
    </a>
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
      |> assign(:user_initials, get_user_initials(user.email))
      |> assign(:member_since, format_member_since(user.inserted_at))

    {:ok, socket}
  end

  defp get_user_initials(email) when is_binary(email) do
    email
    |> String.split("@")
    |> List.first()
    |> String.slice(0, 2)
    |> String.upcase()
  end

  defp get_user_initials(_), do: "?"

  defp format_member_since(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%B %Y")
  end

  defp format_member_since(_), do: ""

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

    if Accounts.sudo_mode?(user) do
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
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("Please re-authenticate to change your email."))
       |> redirect(to: ~p"/users/log-in")}
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

    if Accounts.sudo_mode?(user) do
      case Accounts.change_user_password(user, user_params) do
        %{valid?: true} = changeset ->
          {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

        changeset ->
          {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("Please re-authenticate to change your password."))
       |> redirect(to: ~p"/users/log-in")}
    end
  end

  def handle_event("update_locale", %{"user" => %{"locale" => locale}}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.update_user_locale(user, %{locale: locale}) do
      {:ok, updated_user} ->
        Gettext.put_locale(KlassHeroWeb.Gettext, locale)

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

    case Accounts.delete_account(user, password) do
      {:ok, _anonymized_user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Your account has been deleted."))
         |> redirect(to: ~p"/")}

      {:error, :sudo_required} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Please re-authenticate to delete your account."))
         |> redirect(to: ~p"/users/log-in")}

      {:error, :invalid_password} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Invalid password."))
         |> assign(:delete_form, to_form(%{"password" => ""}, as: :delete))}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete account. Please try again."))
         |> assign(:delete_form, to_form(%{"password" => ""}, as: :delete))}
    end
  end
end
