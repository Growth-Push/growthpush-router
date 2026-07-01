defmodule GrowthPushRouterWeb.EventLive.ShowTest do
  use GrowthPushRouterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents

  test "redirects anonymous users to login", %{conn: conn} do
    {_admin, _owner, event} = create_event_fixture("show-anonymous-events")

    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/events/#{event}")

    assert {:error, {:redirect, %{to: "/login"}}} =
             conn
             |> recycle()
             |> live(~p"/admin/events/#{event}")
  end

  test "redirects normal users away from admin show", %{conn: conn} do
    {_admin, owner, event} = create_event_fixture("show-normal-admin-events")

    assert {:error, {:redirect, %{to: "/dashboard"}}} =
             conn
             |> log_in_user(owner)
             |> live(~p"/admin/events/#{event}")
  end

  test "redirects admin users from user show to admin show", %{conn: conn} do
    {admin, _owner, event} = create_event_fixture("show-admin-user-events")
    admin_event_path = "/admin/events/#{event.id}"

    assert {:error, {:redirect, %{to: ^admin_event_path}}} =
             conn
             |> log_in_user(admin)
             |> live(~p"/events/#{event}")
  end

  test "user sees owned event payload detail", %{conn: conn} do
    {_admin, owner, event} = create_event_fixture("show-owned-events")

    {:ok, _view, html} =
      conn
      |> log_in_user(owner)
      |> live(~p"/events/#{event}")

    assert html =~ "payload"
    assert html =~ "message_received"
    assert html =~ "hello from show-owned-events"
    assert html =~ ~s(href="/events?connection_id=#{event.connection_id}")
  end

  test "user cannot see another owner's event detail", %{conn: conn} do
    {admin, owner, _event} = create_event_fixture("show-owner-events")
    {_other_owner, other_event} = create_other_event_fixture(admin, "show-hidden-events")

    assert {:error, {:redirect, %{to: "/events"}}} =
             conn
             |> log_in_user(owner)
             |> live(~p"/events/#{other_event}")
  end

  test "admin sees event payload detail", %{conn: conn} do
    {admin, _owner, _event} = create_event_fixture("show-admin-events")
    {_other_owner, other_event} = create_other_event_fixture(admin, "show-other-admin-events")

    {:ok, _view, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/events/#{other_event}")

    assert html =~ "payload"
    assert html =~ "hello from show-other-admin-events"
    assert html =~ ~s(href="/admin/events?connection_id=#{other_event.connection_id}")
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
