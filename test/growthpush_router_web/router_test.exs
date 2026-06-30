defmodule GrowthPushRouterWeb.RouterTest do
  use GrowthPushRouterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User

  setup do
    original_mode = Application.get_env(:growthpush_router, :mode)

    on_exit(fn ->
      Application.put_env(:growthpush_router, :mode, original_mode)
    end)
  end

  test "both mode enables browser routes", %{conn: conn} do
    Application.put_env(:growthpush_router, :mode, "both")

    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/login"
  end

  test "edge mode enables admin browser routes", %{conn: conn} do
    Application.put_env(:growthpush_router, :mode, "edge")
    admin = create_admin()

    assert {:ok, _view, html} =
             conn
             |> log_in_user(admin)
             |> live(~p"/admin/users")

    assert html =~ admin.email
  end

  test "agent mode disables browser routes", %{conn: conn} do
    Application.put_env(:growthpush_router, :mode, "agent")

    for path <- [~p"/", ~p"/login", ~p"/admin/users"] do
      conn =
        conn
        |> recycle()
        |> get(path)

      assert conn.status == 404
      assert conn.resp_body == ""
    end
  end

  defp create_admin do
    {:ok, admin} =
      Accounts.upsert_seeded_admin(%{
        "email" => "admin@example.test",
        "name" => "admin",
        "company" => "example"
      })

    admin
  end

  defp log_in_user(conn, %User{} = user) do
    Plug.Test.init_test_session(conn, user_id: user.id, live_socket_id: live_socket_id(user))
  end

  defp live_socket_id(%User{id: id}), do: "users_sessions:#{Base.url_encode64(id)}"
end
