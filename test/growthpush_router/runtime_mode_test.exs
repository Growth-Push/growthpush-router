defmodule GrowthPushRouter.RuntimeModeTest do
  use ExUnit.Case, async: false

  doctest GrowthPushRouter.RuntimeMode

  alias GrowthPushRouter.RuntimeMode

  setup do
    original_mode = Application.get_env(:growthpush_router, :mode)

    on_exit(fn ->
      Application.put_env(:growthpush_router, :mode, original_mode)
    end)
  end

  test "defaults to both when no mode is configured" do
    Application.delete_env(:growthpush_router, :mode)

    assert RuntimeMode.mode() == :both
    assert RuntimeMode.supports?(:edge)
    assert RuntimeMode.supports?(:agent)
  end

  test "supports edge-only mode" do
    Application.put_env(:growthpush_router, :mode, "edge")

    assert RuntimeMode.mode() == :edge
    assert RuntimeMode.supports?(:edge)
    refute RuntimeMode.supports?(:agent)
  end

  test "supports agent-only mode" do
    Application.put_env(:growthpush_router, :mode, "agent")

    assert RuntimeMode.mode() == :agent
    refute RuntimeMode.supports?(:edge)
    assert RuntimeMode.supports?(:agent)
  end

  test "rejects invalid configured modes" do
    Application.put_env(:growthpush_router, :mode, :invalid)

    assert_raise ArgumentError, ~r/invalid GrowthPush runtime mode/, fn ->
      RuntimeMode.mode()
    end
  end
end
