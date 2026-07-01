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

    test "renders owned agents and links Instagram OAuth", %{conn: conn} do
      {admin, user} = create_user()
      {:ok, agent} = create_agent(admin, user, "dashboard-agent")

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/dashboard")

      assert html =~ "dashboard-agent"
      assert html =~ ~p"/connect/instagram?agent_id=#{agent.id}"
      refute html =~ "connection[external_account_id]"
      refute html =~ "placeholder://meta/instagram/account"
    end

    test "deletes an owned Instagram connection from the dashboard", %{conn: conn} do
      {admin, user} = create_user()
      {:ok, agent} = create_agent(admin, user, "delete-dashboard-connection")

      {:ok, connection} =
        Agents.create_connection(admin, valid_connection_params(agent, user))

      {:ok, view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/dashboard")

      assert html =~ "Dashboard IG"
      assert html |> Floki.parse_document!() |> Floki.find("button.btn-error") != []

      html = render_click(view, "request_delete_connection", %{"id" => connection.id})

      assert html =~ "delete-connection-modal"
      assert html =~ "confirm"
      assert {:ok, [_connection]} = Agents.list_connections(user, agent_id: agent.id)

      html =
        view
        |> form("#delete-connection-modal-form", %{
          "connection_delete" => %{"confirmation" => "wrong"}
        })
        |> render_submit()

      assert html =~ "delete-connection-modal"
      assert {:ok, [_connection]} = Agents.list_connections(user, agent_id: agent.id)

      html =
        view
        |> form("#delete-connection-modal-form", %{
          "connection_delete" => %{"confirmation" => "confirm"}
        })
        |> render_submit()

      assert html =~ "conexão excluída"
      assert {:ok, []} = Agents.list_connections(user, agent_id: agent.id)
    end

    test "shows multiple connections for an owned agent", %{conn: conn} do
      {admin, user} = create_user()
      {:ok, agent} = create_agent(admin, user, "multiple-dashboard-connections")

      {:ok, _connection} =
        Agents.create_connection(admin, valid_connection_params(agent, user))

      {:ok, _other_connection} =
        Agents.create_connection(
          admin,
          valid_connection_params(agent, user, %{
            "external_account_id" => "ig-dashboard-account-2",
            "display_name" => "Second IG",
            "access_token_ref" => "oauth://meta/instagram/ig-dashboard-account-2"
          })
        )

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/dashboard")

      assert html =~ "Dashboard IG"
      assert html =~ "Second IG"
    end

    test "does not allow dashboard deletes for another user's connection", %{conn: conn} do
      {admin, user} = create_user()

      {:ok, other_user} =
        Accounts.create_user(admin, %{
          "email" => "other-dashboard-owner@example.com",
          "name" => "Other",
          "company" => "Other Company"
        })

      {:ok, other_agent} = create_agent(admin, other_user, "other-dashboard-agent")

      {:ok, connection} =
        Agents.create_connection(admin, valid_connection_params(other_agent, other_user))

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/dashboard")

      html = render_click(view, "request_delete_connection", %{"id" => connection.id})

      assert html =~ "não foi possível excluir"
      assert {:ok, [_connection]} = Agents.list_connections(other_user, agent_id: other_agent.id)
    end

    test "user connection creation still rejects another user's agent" do
      {admin, user} = create_user()

      {:ok, other_user} =
        Accounts.create_user(admin, %{
          "email" => "other-dashboard-create-owner@example.com",
          "name" => "Other",
          "company" => "Other Company"
        })

      {:ok, other_agent} = create_agent(admin, other_user, "other-dashboard-create-agent")

      assert {:error, :unauthorized} =
               Agents.create_user_connection(user, %{
                 "agent_id" => other_agent.id,
                 "external_account_id" => "other-ig-account",
                 "display_name" => "Other IG",
                 "access_token_ref" => "placeholder://meta/instagram/other"
               })

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

  defp valid_connection_params(agent, user, attrs \\ %{}) do
    Map.merge(
      %{
        "agent_id" => agent.id,
        "connected_by_user_id" => user.id,
        "provider" => "meta",
        "channel" => "instagram",
        "external_account_id" => "ig-dashboard-account",
        "display_name" => "Dashboard IG",
        "access_token_ref" => "oauth://meta/instagram/ig-dashboard-account"
      },
      attrs
    )
  end

  defp live_socket_id(%User{id: id}), do: "users_sessions:#{Base.url_encode64(id)}"
end
