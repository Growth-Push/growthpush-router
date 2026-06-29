defmodule GrowthPushRouter.Repo do
  use Ecto.Repo,
    otp_app: :growthpush_router,
    adapter: Ecto.Adapters.Postgres
end
