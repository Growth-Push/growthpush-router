defmodule GrowthPushRouterWeb.AuthControllerTest do
  use GrowthPushRouterWeb.ConnCase, async: true

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User

  setup do
    %{admin: %User{email: "admin@example.test"}}
  end

  test "login redirects users without password to setup", %{conn: conn, admin: admin} do
    {:ok, user} =
      Accounts.create_user(admin, %{
        "email" => "client@example.com",
        "name" => "Client"
      })

    conn =
      post(conn, ~p"/login", %{
        "user" => %{"email" => user.email, "password" => "anything"}
      })

    assert redirected_to(conn) == ~p"/password/setup?email=#{user.email}"
  end

  test "normal users login into dashboard", %{conn: conn, admin: admin} do
    {:ok, user} =
      Accounts.create_user(admin, %{
        "email" => "client@example.com",
        "name" => "Client"
      })

    {:ok, _user} =
      Accounts.set_initial_password(user, %{
        "password" => "strong-pass",
        "password_confirmation" => "strong-pass"
      })

    conn =
      post(conn, ~p"/login", %{
        "user" => %{"email" => user.email, "password" => "strong-pass"}
      })

    assert redirected_to(conn) == ~p"/dashboard"
    assert get_session(conn, :live_socket_id) == live_socket_id(user)
  end

  test "login honors the stored protected return path", %{conn: conn, admin: admin} do
    {:ok, admin} =
      Accounts.upsert_seeded_admin(%{
        "email" => admin.email,
        "name" => "Admin",
        "company" => "Example"
      })

    {:ok, _admin} =
      Accounts.set_initial_password(admin, %{
        "password" => "strong-pass",
        "password_confirmation" => "strong-pass"
      })

    conn = get(conn, ~p"/admin/users/new")
    assert redirected_to(conn) == ~p"/login"

    conn =
      post(conn, ~p"/login", %{
        "user" => %{"email" => admin.email, "password" => "strong-pass"}
      })

    assert redirected_to(conn) == ~p"/admin/users/new"
  end

  test "logout broadcasts a LiveView disconnect", %{conn: conn, admin: admin} do
    {:ok, admin} =
      Accounts.upsert_seeded_admin(%{
        "email" => admin.email,
        "name" => "Admin",
        "company" => "Example"
      })

    topic = live_socket_id(admin)
    GrowthPushRouterWeb.Endpoint.subscribe(topic)

    conn =
      conn
      |> Plug.Test.init_test_session(user_id: admin.id, live_socket_id: topic)
      |> delete(~p"/logout")

    assert redirected_to(conn) == ~p"/login"
    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "disconnect"}
  end

  test "password setup cannot replace an existing password", %{conn: conn, admin: admin} do
    {:ok, user} =
      Accounts.create_user(admin, %{
        "email" => "client@example.com",
        "name" => "Client"
      })

    {:ok, _user} =
      Accounts.set_initial_password(user, %{
        "password" => "strong-pass",
        "password_confirmation" => "strong-pass"
      })

    conn =
      post(conn, ~p"/password/setup", %{
        "user" => %{
          "email" => user.email,
          "password" => "new-strong-pass",
          "password_confirmation" => "new-strong-pass"
        }
      })

    assert redirected_to(conn) == ~p"/login"
    assert {:ok, _user} = Accounts.authenticate_user(user.email, "strong-pass")
    assert :error = Accounts.authenticate_user(user.email, "new-strong-pass")
  end

  test "password setup works after an admin reset", %{conn: conn, admin: admin} do
    {:ok, user} =
      Accounts.create_user(admin, %{
        "email" => "client@example.com",
        "name" => "Client"
      })

    {:ok, user} =
      Accounts.set_initial_password(user, %{
        "password" => "strong-pass",
        "password_confirmation" => "strong-pass"
      })

    {:ok, _user} = Accounts.reset_user_password(admin, user)

    conn =
      post(conn, ~p"/password/setup", %{
        "user" => %{
          "email" => user.email,
          "password" => "new-strong-pass",
          "password_confirmation" => "new-strong-pass"
        }
      })

    assert redirected_to(conn) == ~p"/dashboard"
    assert {:ok, _user} = Accounts.authenticate_user(user.email, "new-strong-pass")
    assert :error = Accounts.authenticate_user(user.email, "strong-pass")
  end

  defp live_socket_id(%User{id: id}), do: "users_sessions:#{Base.url_encode64(id)}"
end
