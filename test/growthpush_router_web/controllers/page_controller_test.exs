defmodule GrowthPushRouterWeb.PageControllerTest do
  use GrowthPushRouterWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200)
  end
end
