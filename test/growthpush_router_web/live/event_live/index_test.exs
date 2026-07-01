defmodule GrowthPushRouterWeb.EventLive.IndexTest do
  use GrowthPushRouterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents

  test "redirects anonymous users to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/events")

    assert {:error, {:redirect, %{to: "/login"}}} =
             conn
             |> recycle()
             |> live(~p"/admin/events")
  end

  test "redirects normal users away from admin index", %{conn: conn} do
    {_admin, owner, _event} = create_event_fixture("index-normal-admin-events")

    assert {:error, {:redirect, %{to: "/dashboard"}}} =
             conn
             |> log_in_user(owner)
             |> live(~p"/admin/events")
  end

  test "redirects admin users from user index to admin index", %{conn: conn} do
    {admin, _owner, _event} = create_event_fixture("index-admin-user-events")

    assert {:error, {:redirect, %{to: "/admin/events"}}} =
             conn
             |> log_in_user(admin)
             |> live(~p"/events")
  end

  test "user lists only owned events", %{conn: conn} do
    {admin, owner, event} = create_event_fixture("index-owned-events")
    {_other_owner, other_event} = create_other_event_fixture(admin, "index-hidden-events")

    {:ok, _view, html} =
      conn
      |> log_in_user(owner)
      |> live(~p"/events")

    assert html =~ "eventos recebidos"
    assert html =~ event.external_event_id
    refute html =~ other_event.external_event_id
  end

  test "admin index without a connection filter does not list global events", %{conn: conn} do
    {admin, _owner, event} = create_event_fixture("index-admin-events")
    {_other_owner, other_event} = create_other_event_fixture(admin, "index-other-admin-events")

    {:ok, _view, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/events")

    assert html =~ "eventos recebidos"
    assert html =~ "Abra os eventos a partir da conexão de um customer."
    refute html =~ event.external_event_id
    refute html =~ other_event.external_event_id
  end

  test "connection filter limits events", %{conn: conn} do
    {admin, _owner, event} = create_event_fixture("index-filtered-events")

    {_other_owner, other_event} =
      create_other_event_fixture(admin, "index-filtered-hidden-events")

    {:ok, _view, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/events?connection_id=#{event.connection_id}")

    assert html =~ event.external_event_id
    refute html =~ other_event.external_event_id
    assert html =~ "Event Owner"
    assert html =~ "Growth Push index-filtered-events"
    refute html =~ event.connection_id
    refute html =~ "limpar filtros"
  end

  test "dashboard links normal users to events", %{conn: conn} do
    {_admin, owner, _event} = create_event_fixture("index-dashboard-events")

    {:ok, _view, html} =
      conn
      |> log_in_user(owner)
      |> live(~p"/dashboard")

    assert html =~ ~s(href="/events")
    assert html =~ "eventos"
  end

  test "admin nav does not link admins to a global events screen", %{conn: conn} do
    admin = create_admin()

    {:ok, _view, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/users")

    refute html =~ ~s(href="/admin/events")
  end

  defp create_event_fixture(label) do
    admin = create_admin()

    {:ok, owner} =
      Accounts.create_user(admin, %{
        "email" => "#{label}@example.com",
        "name" => "Event Owner"
      })

    {:ok, agent} =
      Agents.create_agent(admin, %{
        "owner_id" => owner.id,
        "slug" => "#{label}-agent",
        "endpoint_url" => "https://agent.example.test/events",
        "shared_secret" => "agent-secret-1234"
      })

    {:ok, connection} =
      Agents.create_connection(admin, %{
        "agent_id" => agent.id,
        "connected_by_user_id" => owner.id,
        "provider" => "meta",
        "channel" => "instagram",
        "external_account_id" => "#{label}-account",
        "display_name" => "Growth Push #{label}",
        "access_token_ref" => "vault://meta/instagram/#{label}"
      })

    {:ok, event} =
      Agents.create_connection_event(agent, connection, %{
        "event_type" => "message_received",
        "external_event_id" => "#{label}-event",
        "payload" => %{"message" => "hello from #{label}"}
      })

    {admin, owner, event}
  end

  defp create_other_event_fixture(%User{} = admin, label) do
    {:ok, owner} =
      Accounts.create_user(admin, %{
        "email" => "#{label}@example.com",
        "name" => "Other Event Owner"
      })

    {:ok, agent} =
      Agents.create_agent(admin, %{
        "owner_id" => owner.id,
        "slug" => "#{label}-agent",
        "endpoint_url" => "https://agent.example.test/events",
        "shared_secret" => "agent-secret-1234"
      })

    {:ok, connection} =
      Agents.create_connection(admin, %{
        "agent_id" => agent.id,
        "connected_by_user_id" => owner.id,
        "provider" => "meta",
        "channel" => "instagram",
        "external_account_id" => "#{label}-account",
        "display_name" => "Growth Push #{label}",
        "access_token_ref" => "vault://meta/instagram/#{label}"
      })

    {:ok, event} =
      Agents.create_connection_event(agent, connection, %{
        "event_type" => "message_received",
        "external_event_id" => "#{label}-event",
        "payload" => %{"message" => "hello from #{label}"}
      })

    {owner, event}
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
