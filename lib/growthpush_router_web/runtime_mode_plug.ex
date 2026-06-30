defmodule GrowthPushRouterWeb.RuntimeModePlug do
  @moduledoc false

  import Plug.Conn

  alias GrowthPushRouter.RuntimeMode

  def init(opts), do: opts

  def call(conn, {:require, capability}) do
    if RuntimeMode.supports?(capability) do
      conn
    else
      not_found(conn)
    end
  end

  def call(conn, :require_edge), do: call(conn, {:require, :edge})
  def call(conn, :require_agent), do: call(conn, {:require, :agent})

  defp not_found(conn) do
    conn
    |> send_resp(:not_found, "")
    |> halt()
  end
end
