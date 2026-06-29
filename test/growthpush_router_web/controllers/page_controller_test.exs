defmodule GrowthPushRouterWeb.PageControllerTest do
  use GrowthPushRouterWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/login"
  end
end
