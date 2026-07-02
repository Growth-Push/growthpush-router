defmodule GrowthPushRouterWeb.MetaWebhookController do
  @moduledoc """
  Handles Meta webhook URL verification.

  Meta calls this public endpoint with `hub.mode`, `hub.verify_token`, and
  `hub.challenge` before it starts sending webhook events. The controller checks
  the verify token configured through `META_WEBHOOK_VERIFY_TOKEN` and echoes the
  challenge when the request is valid.

  This module only verifies callback ownership for Meta setup. It does not
  receive webhook `POST` payloads, validate Meta signatures, or persist provider
  events.
  """

  use GrowthPushRouterWeb, :controller

  @verify_token_config :meta_webhook_verify_token

  def verify(
        conn,
        %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => verify_token,
          "hub.challenge" => challenge
        }
      )
      when is_binary(verify_token) and is_binary(challenge) do
    if valid_verify_token?(verify_token) do
      text(conn, challenge)
    else
      forbidden(conn)
    end
  end

  def verify(conn, _params), do: forbidden(conn)

  defp valid_verify_token?(verify_token) do
    case configured_verify_token() do
      nil -> false
      configured -> secure_compare(configured, verify_token)
    end
  end

  defp configured_verify_token do
    case Application.get_env(:growthpush_router, @verify_token_config) do
      token when is_binary(token) ->
        token
        |> String.trim()
        |> non_empty_token()

      _token ->
        nil
    end
  end

  defp non_empty_token(""), do: nil
  defp non_empty_token(token), do: token

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    Plug.Crypto.secure_compare(left, right)
  end

  defp secure_compare(_left, _right), do: false

  defp forbidden(conn), do: send_resp(conn, :forbidden, "")
end
