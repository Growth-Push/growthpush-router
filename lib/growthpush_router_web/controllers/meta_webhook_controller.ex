defmodule GrowthPushRouterWeb.MetaWebhookController do
  @moduledoc """
  Handles Meta webhook URL verification.

  Meta calls this public endpoint with `hub.mode`, `hub.verify_token`, and
  `hub.challenge` before it starts sending webhook events. The controller checks
  the verify token configured through `META_WEBHOOK_VERIFY_TOKEN` and echoes the
  challenge when the request is valid.

  The `POST` action accepts Meta webhook payloads, maps known payloads to an
  existing provider connection, persists an edge event, and mirrors it into the
  local agent outbox when this node runs in `:both` mode.

  This module does not validate Meta signatures, forward events to remote
  agents, or synchronize CRM/inbox systems.
  """

  use GrowthPushRouterWeb, :controller

  alias GrowthPushRouter.Agents
  alias GrowthPushRouter.Agents.Connection
  alias GrowthPushRouter.RuntimeMode

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

  def create(conn, params) do
    persist_meta_payload(params)

    text(conn, "ok")
  end

  defp persist_meta_payload(params) when is_map(params) do
    with {:ok, external_account_id} <- external_account_id(params),
         {:ok, channel} <- payload_channel(params),
         {:ok, %Connection{agent: agent} = connection} <-
           Agents.fetch_provider_connection("meta", channel, external_account_id),
         {:ok, edge_event} <-
           Agents.create_connection_event(agent, connection, meta_event_attrs(params)) do
      maybe_sync_to_agent(agent, connection, edge_event)
    else
      _unmatched_or_invalid -> :ok
    end
  end

  defp persist_meta_payload(_params), do: :ok

  defp maybe_sync_to_agent(agent, connection, edge_event) do
    if RuntimeMode.supports?(:agent) do
      with {:ok, _agent_event} <-
             Agents.create_agent_event(agent, connection, agent_event_attrs(edge_event)) do
        Agents.mark_event_synced(agent, edge_event)
      end
    else
      {:ok, edge_event}
    end
  end

  defp external_account_id(%{"entry" => [%{"id" => id} | _rest]}) when is_binary(id) do
    id
    |> String.trim()
    |> non_empty_value()
  end

  defp external_account_id(_params), do: :error

  defp payload_channel(%{"object" => "instagram"}), do: {:ok, "instagram"}
  defp payload_channel(_params), do: {:ok, "instagram"}

  defp meta_event_attrs(params) do
    %{
      "event_type" => "meta_webhook_received",
      "external_event_id" => external_event_id_from_payload(params),
      "payload" => params,
      "status" => "received"
    }
  end

  defp agent_event_attrs(edge_event) do
    %{
      "event_type" => edge_event.event_type,
      "external_event_id" => edge_event.external_event_id,
      "payload" => edge_event.payload,
      "received_at" => edge_event.received_at,
      "status" => "received"
    }
  end

  defp external_event_id_from_payload(%{
         "entry" => [%{"messaging" => [%{"message" => %{"mid" => mid}} | _messages]} | _entries]
       })
       when is_binary(mid) do
    mid
  end

  defp external_event_id_from_payload(_params), do: nil

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

  defp non_empty_value(""), do: :error
  defp non_empty_value(value), do: {:ok, value}

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    Plug.Crypto.secure_compare(left, right)
  end

  defp secure_compare(_left, _right), do: false

  defp forbidden(conn), do: send_resp(conn, :forbidden, "")
end
