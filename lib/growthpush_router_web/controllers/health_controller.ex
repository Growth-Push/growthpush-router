defmodule GrowthPushRouterWeb.HealthController do
  use GrowthPushRouterWeb, :controller

  def show(conn, _params), do: text(conn, "ok")
end
