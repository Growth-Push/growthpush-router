defmodule GrowthPushRouterWeb.InternalTestEventControllerTest do
  use GrowthPushRouterWeb.ConnCase, async: true

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents
  alias GrowthPushRouter.Agents.Event
  alias GrowthPushRouter.Repo

  test "requires authentication", %{conn: conn} do
    {_admin, _owner, _agent, connection} = create_connection_fixture("anonymous")

    conn = post(conn, ~p"/internal/test-event", %{"connection_id" => connection.id})

    assert redirected_to(conn) == ~p"/login"
    assert Repo.aggregate(Event, :count) == 0
  end

  test "rejects normal users", %{conn: conn} do
    {_admin, owner, _agent, connection} = create_connection_fixture("normal-user")

    conn =
      conn
      |> log_in_user(owner)
      |> post(~p"/internal/test-event", %{"connection_id" => connection.id})

    assert redirected_to(conn) == ~p"/dashboard"
    assert Repo.aggregate(Event, :count) == 0
  end

  test "admin creates a test event and returns to the requested internal path", %{conn: conn} do
    {admin, owner, _agent, connection} = create_connection_fixture("admin-success")
    return_to = ~p"/admin/users/#{owner}/edit"

    conn =
      conn
      |> log_in_user(admin)
      |> post(~p"/internal/test-event", %{
        "connection_id" => connection.id,
        "return_to" => return_to
      })

    assert redirected_to(conn) == return_to
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "evento de teste"

    assert [edge_event] = Repo.all_by(Event, stored_by: "edge")
    assert [agent_event] = Repo.all_by(Event, stored_by: "agent")

    assert edge_event.connection_id == connection.id
    assert edge_event.event_type == "test_event"
    assert edge_event.status == "synced"
    assert edge_event.processed_at
    assert edge_event.external_event_id =~ "test-event-#{connection.id}-"
    assert edge_event.payload["object"] == "instagram"
    assert [%{"id" => "admin-success-instagram-account"}] = edge_event.payload["entry"]

    assert agent_event.connection_id == connection.id
    assert agent_event.event_type == "test_event"
    assert agent_event.status == "received"
    assert agent_event.stored_by == "agent"
    assert agent_event.external_event_id == edge_event.external_event_id
  end

  test "admin can return to the events list filtered by connection", %{conn: conn} do
    {admin, _owner, _agent, connection} = create_connection_fixture("admin-events-return")
    return_to = ~p"/admin/events?connection_id=#{connection.id}"

    conn =
      conn
      |> log_in_user(admin)
      |> post(~p"/internal/test-event", %{
        "connection_id" => connection.id,
        "return_to" => return_to
      })

    assert redirected_to(conn) == return_to

    assert %Event{connection_id: connection_id, status: "synced"} =
             Repo.get_by(Event, stored_by: "edge")

    assert %Event{connection_id: ^connection_id, status: "received"} =
             Repo.get_by(Event, stored_by: "agent")

    assert connection_id == connection.id
  end

  test "admin receives an error for invalid connection ids", %{conn: conn} do
    {admin, _owner, _agent, _connection} = create_connection_fixture("admin-invalid")

    conn =
      conn
      |> log_in_user(admin)
      |> post(~p"/internal/test-event", %{
        "connection_id" => "not-a-uuid",
        "return_to" => "/admin/users"
      })

    assert redirected_to(conn) == ~p"/admin/users"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "evento de teste"
    assert Repo.aggregate(Event, :count) == 0
  end

  defp create_connection_fixture(label) do
    admin = create_admin()

    {:ok, owner} =
      Accounts.create_user(admin, %{
        "email" => "#{label}-test-event@example.com",
        "name" => "Test Event User"
      })

    {:ok, agent} =
      Agents.create_agent(admin, %{
        "owner_id" => owner.id,
        "slug" => "#{label}-test-event-agent",
        "endpoint_url" => "https://agent.example.test/events",
        "shared_secret" => "agent-secret-1234"
      })

    {:ok, connection} =
      Agents.create_connection(admin, %{
        "agent_id" => agent.id,
        "connected_by_user_id" => owner.id,
        "provider" => "meta",
        "channel" => "instagram",
        "external_account_id" => "#{label}-instagram-account",
        "display_name" => "Test Event Instagram",
        "access_token_ref" => "vault://meta/instagram/#{label}"
      })

    {admin, owner, agent, connection}
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
