defmodule GrowthPushRouterWeb.Router do
  use GrowthPushRouterWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GrowthPushRouterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug GrowthPushRouterWeb.UserAuth, :fetch_current_user
  end

  pipeline :redirect_if_authenticated do
    plug GrowthPushRouterWeb.UserAuth, :redirect_if_user_is_authenticated
  end

  pipeline :authenticated do
    plug GrowthPushRouterWeb.UserAuth, :require_authenticated_user
  end

  pipeline :admin do
    plug GrowthPushRouterWeb.UserAuth, :require_admin_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GrowthPushRouterWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", GrowthPushRouterWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    live "/login", SessionLive.New, :new
    post "/login", SessionController, :create
    live "/password/setup", PasswordSetupLive.New, :new
    post "/password/setup", PasswordSetupController, :create
  end

  scope "/", GrowthPushRouterWeb do
    pipe_through [:browser, :authenticated]

    delete "/logout", SessionController, :delete
    live "/dashboard", DashboardLive.Index, :index
  end

  scope "/admin", GrowthPushRouterWeb do
    pipe_through [:browser, :admin]

    live "/users", AdminUserLive.Index, :index
    live "/users/new", AdminUserLive.Form, :new
    live "/users/:id/edit", AdminUserLive.Form, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", GrowthPushRouterWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:growthpush_router, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GrowthPushRouterWeb.Telemetry
    end
  end
end
