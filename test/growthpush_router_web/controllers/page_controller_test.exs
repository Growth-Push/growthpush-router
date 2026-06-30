defmodule GrowthPushRouterWeb.PageControllerTest do
  use GrowthPushRouterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User

  setup do
    original_privacy_email = Application.get_env(:growthpush_router, :privacy_email)

    on_exit(fn ->
      if is_nil(original_privacy_email) do
        Application.delete_env(:growthpush_router, :privacy_email)
      else
        Application.put_env(:growthpush_router, :privacy_email, original_privacy_email)
      end
    end)
  end

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/login"
  end

  test "GET / redirects admins to user management", %{conn: conn} do
    admin = create_admin()

    conn =
      conn
      |> log_in_user(admin)
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/admin/users"
  end

  test "GET / redirects normal users to dashboard", %{conn: conn} do
    {_admin, user} = create_user()

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/dashboard"
  end

  test "GET /health is public", %{conn: conn} do
    conn = get(conn, ~p"/health")

    assert conn.status == 200
    assert conn.resp_body == "ok"
  end

  test "GET /privacy is public and renders policy copy", %{conn: conn} do
    Application.put_env(:growthpush_router, :privacy_email, "privacy@example.test")

    assert {:ok, _view, html} = live(conn, ~p"/privacy")

    assert html =~ "política de privacidade"
    assert html =~ "e-mail, nome, empresa"
    assert html =~ "hash de senha"
    assert html =~ "configurações de agentes e conexões"
    assert html =~ "payloads de webhook"
    assert html =~ "privacy@example.test"
  end

  test "GET /data-deletion is public and renders deletion instructions", %{conn: conn} do
    Application.put_env(:growthpush_router, :privacy_email, "privacy@example.test")

    assert {:ok, _view, html} = live(conn, ~p"/data-deletion")

    assert html =~ "exclusão de dados"
    assert html =~ "contas de usuário do app"
    assert html =~ "identificadores de contas de provedores"
    assert html =~ "solicitar exclusão"
    assert html =~ "privacy@example.test"
  end

  defp create_user do
    admin = create_admin()

    {:ok, user} =
      Accounts.create_user(admin, %{
        "email" => "client@example.com",
        "name" => "client",
        "company" => "client company"
      })

    {admin, user}
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
