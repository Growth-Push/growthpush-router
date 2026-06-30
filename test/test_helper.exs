Application.put_env(:growthpush_router, :admin_emails, ["admin@example.test"])
Application.put_env(:growthpush_router, :mode, "both")

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(GrowthPushRouter.Repo, :manual)
