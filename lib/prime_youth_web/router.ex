defmodule PrimeYouthWeb.Router do
  use PrimeYouthWeb, :router

  import PrimeYouthWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PrimeYouthWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PrimeYouthWeb do
    pipe_through :browser

    # Public routes (no authentication required)
    live_session :public, layout: {PrimeYouthWeb.Layouts, :app} do
      live "/", HomeLive, :index
      live "/programs", ProgramsLive, :index
      live "/programs/:id", ProgramDetailLive, :show
      live "/programs/:id/booking", BookingLive, :new
      live "/about", AboutLive, :index
      live "/contact", ContactLive, :index
    end

    # Authenticated routes (require login)
    # TODO: Add on_mount hook for authentication check
    live_session :authenticated, layout: {PrimeYouthWeb.Layouts, :app} do
      live "/dashboard", DashboardLive, :index
      live "/highlights", HighlightsLive, :index
      live "/settings", SettingsLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", PrimeYouthWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:prime_youth, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PrimeYouthWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", PrimeYouthWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PrimeYouthWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", PrimeYouthWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{PrimeYouthWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
