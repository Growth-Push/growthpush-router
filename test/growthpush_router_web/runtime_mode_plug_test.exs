defmodule GrowthPushRouterWeb.RuntimeModePlugTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias GrowthPushRouterWeb.RuntimeModePlug

  setup do
    original_mode = Application.get_env(:growthpush_router, :mode)

    on_exit(fn ->
      Application.put_env(:growthpush_router, :mode, original_mode)
    end)
  end

  test "edge mode enables edge routes and disables agent routes" do
    Application.put_env(:growthpush_router, :mode, "edge")

    refute call(:edge).halted
    assert blocked?(call(:agent))
  end

  test "agent mode enables agent routes and disables edge routes" do
    Application.put_env(:growthpush_router, :mode, "agent")

    assert blocked?(call(:edge))
    refute call(:agent).halted
  end

  test "both mode enables edge and agent routes" do
    Application.put_env(:growthpush_router, :mode, "both")

    refute call(:edge).halted
    refute call(:agent).halted
  end

  defp call(capability) do
    :get
    |> conn("/")
    |> RuntimeModePlug.call({:require, capability})
  end

  defp blocked?(conn), do: conn.halted && conn.status == 404 && conn.resp_body == ""
end
