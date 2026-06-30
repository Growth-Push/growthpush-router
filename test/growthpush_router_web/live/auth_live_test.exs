defmodule GrowthPushRouterWeb.AuthLiveTest do
  use GrowthPushRouterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents

  describe "session live" do
    test "renders the login form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/login")

      assert html =~ "entrar"
      assert html =~ "user[email]"
      assert html =~ "user[password]"
    end

    test "redirects authenticated users away from login", %{conn: conn} do
      {_admin, user} = create_user()

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/login")
    end
  end

  describe "password setup live" do
    test "renders the setup form with an email from params", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/password/setup?email=client@example.com")

      assert html =~ "definir senha"
      assert html =~ "client@example.com"
      assert html =~ "user[password_confirmation]"
    end

    test "redirects authenticated users away from password setup", %{conn: conn} do
      {_admin, user} = create_user()

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/password/setup")
    end

    test "validates password input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/password/setup")

      html =
        render_change(view, "validate", %{
          "user" => %{
            "email" => "client@example.com",
            "password" => "short",
            "password_confirmation" => "other"
          }
        })

      assert html =~ "client@example.com"
      assert html =~ "não corresponde"
    end
  end

  describe "dashboard live" do
    test "redirects anonymous users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard")
    end

    test "redirects admin users to user management", %{conn: conn} do
      admin = create_admin()

      assert {:error, {:redirect, %{to: "/admin/users"}}} =
               conn
               |> log_in_user(admin)
               |> live(~p"/dashboard")
    end

    test "renders the current normal user dashboard", %{conn: conn} do
      {_admin, user} = create_user()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/dashboard")

      assert html =~ "dashboard"
      assert html =~ user.email
      assert html =~ "client company"
    end

    test "renders owned agents and creates a manual Instagram connection", %{conn: conn} do
      {admin, user} = create_user()
      {:ok, agent} = create_agent(admin, user, "dashboard-agent")

      {:ok, view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/dashboard")

      assert html =~ "dashboard-agent"
      assert html =~ "connection[external_account_id]"
      assert html =~ "placeholder://meta/instagram/account"

      html =
        view
        |> form("#instagram-connection-form-#{agent.id}", %{
          "agent_id" => agent.id,
          "connection" => %{
            "external_account_id" => "ig-dashboard-account",
            "display_name" => "Dashboard IG",
            "access_token_ref" => "placeholder://meta/instagram/dashboard"
          }
        })
        |> render_submit()

      assert html =~ "Instagram conectado"
      assert html =~ "Dashboard IG"
      refute html =~ "placeholder://meta/instagram/dashboard"

      assert {:ok, [connection]} = Agents.list_connections(user, agent_id: agent.id)
      assert connection.connected_by_user_id == user.id
      assert connection.provider == "meta"
      assert connection.channel == "instagram"
      assert connection.access_token_ref == "placeholder://meta/instagram/dashboard"
    end

    test "does not allow dashboard events for another user's agent", %{conn: conn} do
      {admin, user} = create_user()

      {:ok, other_user} =
        Accounts.create_user(admin, %{
          "email" => "other-dashboard-owner@example.com",
          "name" => "Other",
          "company" => "Other Company"
        })

      {:ok, other_agent} = create_agent(admin, other_user, "other-dashboard-agent")

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/dashboard")

      html =
        render_submit(view, "save_connection", %{
          "agent_id" => other_agent.id,
          "connection" => %{
            "external_account_id" => "other-ig-account",
            "display_name" => "Other IG",
            "access_token_ref" => "placeholder://meta/instagram/other"
          }
        })

      assert html =~ "agent não encontrado"
      assert {:ok, []} = Agents.list_connections(user)
    end

    test "logout redirects an already connected dashboard LiveView", %{conn: conn} do
      {_admin, user} = create_user()
      logged_in_conn = log_in_user(conn, user)

      {:ok, view, _html} = live(logged_in_conn, ~p"/dashboard")

      logged_in_conn
      |> delete(~p"/logout")
      |> redirected_to()

      assert_redirect(view, ~p"/login")
    end
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

  defp create_agent(%User{} = admin, %User{} = owner, slug) do
    Agents.create_agent(admin, %{
      "owner_id" => owner.id,
      "slug" => slug,
      "endpoint_url" => "https://agent.example.test/events",
      "shared_secret" => "agent-secret-1234"
    })
  end

  defp live_socket_id(%User{id: id}), do: "users_sessions:#{Base.url_encode64(id)}"
end
