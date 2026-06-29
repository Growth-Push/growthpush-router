defmodule GrowthPushRouter.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Hammer.Backend.ETS, expiry_ms: 60_000 * 60, cleanup_interval_ms: 60_000 * 10},
      {Finch, name: GrowthPushRouter.Finch},
      GrowthPushRouterWeb.Telemetry,
      GrowthPushRouter.Repo,
      {DNSCluster, query: Application.get_env(:growthpush_router, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:growthpush_router, Oban)},
      {Phoenix.PubSub, name: GrowthPushRouter.PubSub},
      # Start a worker by calling: GrowthPushRouter.Worker.start_link(arg)
      # {GrowthPushRouter.Worker, arg},
      # Start to serve requests, typically the last entry
      GrowthPushRouterWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GrowthPushRouter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GrowthPushRouterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
