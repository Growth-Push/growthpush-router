defmodule GrowthPushRouterWeb.PageController do
  use GrowthPushRouterWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
