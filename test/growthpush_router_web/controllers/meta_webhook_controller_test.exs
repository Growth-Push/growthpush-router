defmodule GrowthPushRouterWeb.MetaWebhookControllerTest do
  use GrowthPushRouterWeb.ConnCase

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents
  alias GrowthPushRouter.Agents.Event
  alias GrowthPushRouter.Repo

  @verify_token "meta-webhook-verify-token"
  @challenge "1234567890"

  setup do
    original_mode = Application.get_env(:growthpush_router, :mode)
    original_verify_token = Application.get_env(:growthpush_router, :meta_webhook_verify_token)

    Application.put_env(:growthpush_router, :mode, "edge")
    Application.put_env(:growthpush_router, :meta_webhook_verify_token, @verify_token)

    on_exit(fn ->
      restore_env(:mode, original_mode)
      restore_env(:meta_webhook_verify_token, original_verify_token)
    end)
  end

  test "GET /webhooks/meta returns the challenge for a valid Meta verification", %{conn: conn} do
    conn = get(conn, ~p"/webhooks/meta", valid_params())

    assert conn.status == 200
    assert conn.resp_body == @challenge
  end

  test "GET /webhooks/meta does not require a signed-in user", %{conn: conn} do
    conn = get(conn, ~p"/webhooks/meta", valid_params())

    assert conn.status == 200
    assert conn.resp_body == @challenge
  end

  test "GET /webhooks/meta rejects invalid verification tokens", %{conn: conn} do
    conn =
      get(conn, ~p"/webhooks/meta", %{
        "hub.mode" => "subscribe",
        "hub.verify_token" => "wrong-token",
        "hub.challenge" => @challenge
      })

    assert conn.status == 403
    assert conn.resp_body == ""
  end

  test "GET /webhooks/meta rejects requests when the configured token is missing", %{conn: conn} do
    Application.delete_env(:growthpush_router, :meta_webhook_verify_token)

    conn = get(conn, ~p"/webhooks/meta", valid_params())

    assert conn.status == 403
    assert conn.resp_body == ""
  end

  test "GET /webhooks/meta rejects non-subscribe modes", %{conn: conn} do
    conn =
      get(conn, ~p"/webhooks/meta", %{
        "hub.mode" => "unsubscribe",
        "hub.verify_token" => @verify_token,
        "hub.challenge" => @challenge
      })

    assert conn.status == 403
    assert conn.resp_body == ""
  end

  test "GET /webhooks/meta rejects missing challenge params", %{conn: conn} do
    conn =
      get(conn, ~p"/webhooks/meta", %{
        "hub.mode" => "subscribe",
        "hub.verify_token" => @verify_token
      })

    assert conn.status == 403
    assert conn.resp_body == ""
  end

  test "GET /webhooks/meta is available in both mode", %{conn: conn} do
    Application.put_env(:growthpush_router, :mode, "both")

    conn = get(conn, ~p"/webhooks/meta", valid_params())

    assert conn.status == 200
    assert conn.resp_body == @challenge
  end

  test "GET /webhooks/meta is not available in agent mode", %{conn: conn} do
    Application.put_env(:growthpush_router, :mode, "agent")

    conn = get(conn, ~p"/webhooks/meta", valid_params())

    assert conn.status == 404
    assert conn.resp_body == ""
  end

  test "POST /webhooks/meta creates an edge event for a matched connection", %{conn: conn} do
    {_admin, _owner, _agent, connection} = create_connection_fixture("edge-post")

    conn = post(conn, ~p"/webhooks/meta", instagram_payload(connection.external_account_id))

    assert conn.status == 200
    assert conn.resp_body == "ok"

    assert [edge_event] = Repo.all_by(Event, stored_by: "edge")
    assert Repo.all_by(Event, stored_by: "agent") == []

    assert edge_event.connection_id == connection.id
    assert edge_event.provider == "meta"
    assert edge_event.channel == "instagram"
    assert edge_event.event_type == "meta_webhook_received"
    assert edge_event.external_event_id == "mid-edge-post-account"
    assert edge_event.status == "received"
    assert edge_event.payload["object"] == "instagram"
    assert [%{"id" => "edge-post-account"}] = edge_event.payload["entry"]
  end

  test "POST /webhooks/meta mirrors matched events to the agent outbox in both mode", %{
    conn: conn
  } do
    Application.put_env(:growthpush_router, :mode, "both")
    {_admin, _owner, _agent, connection} = create_connection_fixture("both-post")

    conn = post(conn, ~p"/webhooks/meta", instagram_payload(connection.external_account_id))

    assert conn.status == 200
    assert conn.resp_body == "ok"

    assert [edge_event] = Repo.all_by(Event, stored_by: "edge")
    assert [agent_event] = Repo.all_by(Event, stored_by: "agent")

    assert edge_event.connection_id == connection.id
    assert edge_event.status == "synced"
    assert edge_event.processed_at
    assert edge_event.external_event_id == "mid-both-post-account"

    assert agent_event.connection_id == connection.id
    assert agent_event.status == "received"
    assert agent_event.event_type == edge_event.event_type
    assert agent_event.external_event_id == edge_event.external_event_id
    assert agent_event.payload == edge_event.payload
  end

  test "POST /webhooks/meta ignores unknown payload shapes without failing", %{conn: conn} do
    conn = post(conn, ~p"/webhooks/meta", %{"object" => "instagram", "entry" => []})

    assert conn.status == 200
    assert conn.resp_body == "ok"
    assert Repo.aggregate(Event, :count) == 0
  end

  test "POST /webhooks/meta ignores payloads for unknown external accounts", %{conn: conn} do
    conn = post(conn, ~p"/webhooks/meta", instagram_payload("unknown-instagram-account"))

    assert conn.status == 200
    assert conn.resp_body == "ok"
    assert Repo.aggregate(Event, :count) == 0
  end

  test "POST /webhooks/meta is not available in agent mode", %{conn: conn} do
    Application.put_env(:growthpush_router, :mode, "agent")

    conn = post(conn, ~p"/webhooks/meta", instagram_payload("agent-mode-account"))

    assert conn.status == 404
    assert conn.resp_body == ""
    assert Repo.aggregate(Event, :count) == 0
  end

  defp valid_params do
    %{
      "hub.mode" => "subscribe",
      "hub.verify_token" => @verify_token,
      "hub.challenge" => @challenge
    }
  end

  defp instagram_payload(external_account_id) do
    %{
      "object" => "instagram",
      "entry" => [
        %{
          "id" => external_account_id,
          "time" => 1_783_000_000,
          "messaging" => [
            %{
              "message" => %{
                "mid" => "mid-#{external_account_id}",
                "text" => "Webhook message"
              },
              "recipient" => %{"id" => external_account_id},
              "sender" => %{"id" => "sender-#{external_account_id}"},
              "timestamp" => 1_783_000_000_000
            }
          ]
        }
      ]
    }
  end

  defp create_connection_fixture(label) do
    admin = create_admin()

    {:ok, owner} =
      Accounts.create_user(admin, %{
        "email" => "#{label}-webhook@example.com",
        "name" => "Meta Webhook User"
      })

    {:ok, agent} =
      Agents.create_agent(admin, %{
        "owner_id" => owner.id,
        "slug" => "#{label}-webhook-agent",
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
        "display_name" => "Meta Webhook Instagram",
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

    User.with_runtime_role(admin)
  end

  defp restore_env(key, nil), do: Application.delete_env(:growthpush_router, key)
  defp restore_env(key, value), do: Application.put_env(:growthpush_router, key, value)
end
