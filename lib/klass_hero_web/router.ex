defmodule KlassHeroWeb.Router do
  use KlassHeroWeb, :router

  import KlassHeroWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KlassHeroWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug KlassHeroWeb.Plugs.SetLocale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", KlassHeroWeb do
    pipe_through :browser

    # Public routes - optional authentication
    live_session :public,
      layout: {KlassHeroWeb.Layouts, :app},
      on_mount: [
        {KlassHeroWeb.UserAuth, :mount_current_scope},
        {KlassHeroWeb.Hooks.RestoreLocale, :restore_locale}
      ] do
      live "/", HomeLive, :index
      live "/programs", ProgramsLive, :index
      live "/programs/:id", ProgramDetailLive, :show
      live "/about", AboutLive, :index
      live "/contact", ContactLive, :index
      live "/privacy", PrivacyPolicyLive, :index
      live "/terms", TermsOfServiceLive, :index
    end

    # Protected routes - authentication required
    live_session :authenticated,
      layout: {KlassHeroWeb.Layouts, :app},
      on_mount: [
        {KlassHeroWeb.UserAuth, :require_authenticated},
        {KlassHeroWeb.Hooks.RestoreLocale, :restore_locale}
      ] do
      live "/dashboard", DashboardLive, :index
      live "/settings", SettingsLive, :index
      live "/programs/:id/booking", BookingLive, :new
    end

    # Provider routes - provider role required
    live_session :require_provider,
      layout: {KlassHeroWeb.Layouts, :app},
      on_mount: [
        {KlassHeroWeb.UserAuth, :require_authenticated},
        {KlassHeroWeb.UserAuth, :require_provider},
        {KlassHeroWeb.Hooks.RestoreLocale, :restore_locale}
      ] do
      scope "/provider", Provider do
        live "/sessions", SessionsLive, :index
        live "/participation/:session_id", ParticipationLive, :show
      end
    end

    # Parent routes - parent role required
    live_session :require_parent,
      layout: {KlassHeroWeb.Layouts, :app},
      on_mount: [
        {KlassHeroWeb.UserAuth, :require_authenticated},
        {KlassHeroWeb.UserAuth, :require_parent},
        {KlassHeroWeb.Hooks.RestoreLocale, :restore_locale}
      ] do
      scope "/parent", Parent do
        live "/participation", ParticipationHistoryLive, :index
      end
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", KlassHeroWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:klass_hero, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: KlassHeroWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes
  ## Will be added by mix phx.gen.auth

  ## Authentication routes

  scope "/", KlassHeroWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      layout: {KlassHeroWeb.Layouts, :app},
      on_mount: [
        {KlassHeroWeb.UserAuth, :require_authenticated},
        {KlassHeroWeb.Hooks.RestoreLocale, :restore_locale}
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
    get "/users/export-data", UserDataExportController, :export
  end

  scope "/", KlassHeroWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        {KlassHeroWeb.UserAuth, :mount_current_scope},
        {KlassHeroWeb.Hooks.RestoreLocale, :restore_locale}
      ] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  if Application.compile_env(:klass_hero, :dev_routes) do
    use ErrorTracker.Web, :router

    scope "/dev" do
      pipe_through :browser

      error_tracker_dashboard "/errors"
    end
  end
end
