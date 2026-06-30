defmodule GrowthPushRouterWeb.InstagramAuthController do
  @moduledoc """
  Placeholder endpoints for the future Instagram OAuth flow.

  The MVP supports manual Instagram connections, but Meta app setup still
  expects stable connect and callback URLs. These actions keep those routes
  authenticated and predictable without pretending to perform a real OAuth
  exchange or storing provider tokens.
  """

  use GrowthPushRouterWeb, :controller

  def connect(conn, _params) do
    conn
    |> put_flash(:info, gettext(".instagram_connect.oauth_unavailable"))
    |> redirect(to: ~p"/dashboard")
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:info, gettext(".instagram_connect.callback_unavailable"))
    |> redirect(to: ~p"/dashboard")
  end
end
