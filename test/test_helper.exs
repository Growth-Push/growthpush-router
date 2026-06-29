Application.put_env(:growthpush_router, :admin_emails, ["admin@example.test"])

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(GrowthPushRouter.Repo, :manual)
