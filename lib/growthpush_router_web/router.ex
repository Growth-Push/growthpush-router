defmodule GrowthPushRouterWeb.Router do
  use GrowthPushRouterWeb, :router

  # Runtime-mode gates. Put these first in each scope so the router shows which
  # surfaces belong to edge nodes and which belong to agent nodes.
  pipeline :edge do
    plug GrowthPushRouterWeb.RuntimeModePlug, {:require, :edge}
  end

  pipeline :agent do
    plug GrowthPushRouterWeb.RuntimeModePlug, {:require, :agent}
  end

  # Browser/LiveView stack. Edge UI routes use this after the mode gate.
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GrowthPushRouterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug GrowthPushRouterWeb.UserAuth, :fetch_current_user
  end

  # Browser auth refinements. These only make sense after :browser has loaded
  # the session and current user.
  pipeline :redirect_if_authenticated do
    plug GrowthPushRouterWeb.UserAuth, :redirect_if_user_is_authenticated
  end

  pipeline :authenticated do
    plug GrowthPushRouterWeb.UserAuth, :require_authenticated_user
  end

  pipeline :admin do
    plug GrowthPushRouterWeb.UserAuth, :require_admin_user
  end

  # JSON API stack. Agent-facing API endpoints should use [:agent, :api].
  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public infrastructure endpoint. Health stays outside edge/agent mode gates
  # so deployment checks can reach every node type.
  scope "/", GrowthPushRouterWeb do
    get "/health", HealthController, :show
  end

  # Edge API endpoints. Providers call these webhook routes; they are not
  # browser or LiveView routes.
  scope "/webhooks", GrowthPushRouterWeb do
    pipe_through [:edge]

    get "/meta", MetaWebhookController, :verify
    post "/meta", MetaWebhookController, :create
  end

  # Edge public HTML/LiveView routes. These are browser-visible pages that do
  # not require an authenticated user.
  scope "/", GrowthPushRouterWeb do
    pipe_through [:edge, :browser]

    get "/", PageController, :home
    live "/privacy", PrivacyLive.Show, :show
    live "/data-deletion", DataDeletionLive.Show, :show
  end

  # Edge auth HTML/LiveView routes. Anonymous users can reach these; signed-in
  # users are redirected away.
  scope "/", GrowthPushRouterWeb do
    pipe_through [:edge, :browser, :redirect_if_authenticated]

    live "/login", SessionLive.New, :new
    post "/login", SessionController, :create
    live "/password/setup", PasswordSetupLive.New, :new
    post "/password/setup", PasswordSetupController, :create
  end

  # Edge authenticated app routes. LiveViews are the default for user-facing UI;
  # controllers here are redirect/session/OAuth endpoints.
  scope "/", GrowthPushRouterWeb do
    pipe_through [:edge, :browser, :authenticated]

    delete "/logout", SessionController, :delete
    live "/dashboard", DashboardLive.Index, :index
    get "/connect/instagram", InstagramAuthController, :connect
    get "/auth/instagram/callback", InstagramAuthController, :callback
    live "/events", EventLive.Index, :index
    live "/events/:id", EventLive.Show, :show
  end

  # Edge admin LiveView routes. Admin-only screens stay on the browser surface.
  scope "/admin", GrowthPushRouterWeb do
    pipe_through [:edge, :browser, :admin]

    live "/users", AdminUserLive.Index, :index
    live "/users/new", AdminUserLive.Form, :new
    live "/users/:id/edit", AdminUserLive.Form, :edit
    live "/events", EventLive.Index, :admin_index
    live "/events/:id", EventLive.Show, :admin_show
  end

  # Edge admin utility endpoints. These are browser-authenticated actions used
  # from the admin UI, not external API endpoints.
  scope "/internal", GrowthPushRouterWeb do
    pipe_through [:edge, :browser, :admin]

    post "/test-event", InternalTestEventController, :create
  end

  # Agent API endpoints. Add agent-owned JSON routes here so they are clearly
  # separated from the edge browser surface.
  # scope "/api", GrowthPushRouterWeb do
  #   pipe_through [:agent, :api]
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
      pipe_through [:edge, :browser]

      live_dashboard "/dashboard", metrics: GrowthPushRouterWeb.Telemetry
    end
  end
end
