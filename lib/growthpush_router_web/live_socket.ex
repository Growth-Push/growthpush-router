defmodule GrowthPushRouterWeb.LiveSocket do
  @moduledoc """
  LiveView socket wrapper that enforces GrowthPush runtime mode.

  Browser routes are guarded in `GrowthPushRouterWeb.Router`, but LiveView
  websocket and longpoll traffic is mounted directly in
  `GrowthPushRouterWeb.Endpoint` at `/live`. This socket keeps agent-mode nodes
  from serving interactive browser LiveViews when `/live` traffic reaches them.
  """

  use Phoenix.LiveView.Socket

  alias GrowthPushRouter.RuntimeMode

  @impl Phoenix.Socket
  def connect(params, socket, connect_info) do
    if RuntimeMode.supports?(:edge) do
      super(params, socket, connect_info)
    else
      :error
    end
  end

  @impl Phoenix.Socket
  def id(socket), do: Phoenix.LiveView.Socket.id(socket)
end
