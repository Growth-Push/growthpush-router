defmodule GrowthPushRouterWeb.MetaWebhookControllerTest do
  use GrowthPushRouterWeb.ConnCase

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

  defp valid_params do
    %{
      "hub.mode" => "subscribe",
      "hub.verify_token" => @verify_token,
      "hub.challenge" => @challenge
    }
  end

  defp restore_env(key, nil), do: Application.delete_env(:growthpush_router, key)
  defp restore_env(key, value), do: Application.put_env(:growthpush_router, key, value)
end
