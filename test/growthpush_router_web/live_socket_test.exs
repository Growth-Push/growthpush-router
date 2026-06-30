defmodule GrowthPushRouterWeb.LiveSocketTest do
  use ExUnit.Case, async: false

  import Phoenix.ChannelTest

  @endpoint GrowthPushRouterWeb.Endpoint

  setup do
    original_mode = Application.get_env(:growthpush_router, :mode)

    on_exit(fn ->
      Application.put_env(:growthpush_router, :mode, original_mode)
    end)
  end

  test "agent mode rejects LiveView socket connections" do
    Application.put_env(:growthpush_router, :mode, "agent")

    assert :error = connect(GrowthPushRouterWeb.LiveSocket, %{})
  end

  test "edge mode accepts LiveView socket connections" do
    Application.put_env(:growthpush_router, :mode, "edge")

    assert {:ok, socket} =
             connect(GrowthPushRouterWeb.LiveSocket, %{},
               connect_info: %{session: %{"live_socket_id" => "users_sessions:test"}}
             )

    assert socket.id == "users_sessions:test"
  end

  test "both mode accepts LiveView socket connections" do
    Application.put_env(:growthpush_router, :mode, "both")

    assert {:ok, _socket} = connect(GrowthPushRouterWeb.LiveSocket, %{})
  end
end
