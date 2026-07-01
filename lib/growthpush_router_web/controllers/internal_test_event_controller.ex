defmodule GrowthPushRouterWeb.InternalTestEventController do
  @moduledoc """
  Internal admin endpoint for generating demo connection events.
  """

  use GrowthPushRouterWeb, :controller

  alias GrowthPushRouter.Agents

  @doc """
  Handles `POST /internal/test-event` for admin-triggered demo events.

  The endpoint accepts a `connection_id`, creates a persisted Instagram-shaped
  test event without calling Meta, and redirects back to the provided internal
  `return_to` path or the admin user list.
  """
  def create(conn, params) do
    conn
    |> create_test_event(params)
    |> handle_create_result(conn, params)
  end

  defp create_test_event(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, connection} <- Agents.fetch_connection(current_user, connection_id(params)),
         {:ok, agent} <- Agents.fetch_agent(current_user, connection.agent_id) do
      Agents.create_connection_event(agent, connection, test_event_attrs(connection))
    end
  end

  defp handle_create_result({:ok, _event}, conn, params) do
    conn
    |> put_flash(:info, gettext(".test_event.created"))
    |> redirect(to: return_to(params))
  end

  defp handle_create_result({:error, _reason}, conn, params) do
    conn
    |> put_flash(:error, gettext(".test_event.failed"))
    |> redirect(to: return_to(params))
  end

  defp connection_id(%{"connection_id" => connection_id}), do: connection_id
  defp connection_id(%{"test_event" => %{"connection_id" => connection_id}}), do: connection_id
  defp connection_id(_params), do: nil

  defp test_event_attrs(connection) do
    event_id = "test-event-#{connection.id}-#{System.unique_integer([:positive])}"

    %{
      "event_type" => "test_event",
      "external_event_id" => event_id,
      "payload" => test_instagram_payload(connection, event_id),
      "status" => "received"
    }
  end

  defp test_instagram_payload(connection, event_id) do
    %{
      "object" => "instagram",
      "entry" => [
        %{
          "id" => connection.external_account_id,
          "time" => DateTime.utc_now(:second) |> DateTime.to_unix(),
          "messaging" => [
            %{
              "message" => %{
                "mid" => event_id,
                "text" => "Growth Push internal test event"
              },
              "recipient" => %{"id" => connection.external_account_id},
              "sender" => %{"id" => "internal-test-sender"},
              "timestamp" => System.system_time(:millisecond)
            }
          ]
        }
      ]
    }
  end

  defp return_to(%{"return_to" => "/" <> _path = return_to}), do: return_to
  defp return_to(%{"test_event" => %{"return_to" => "/" <> _path = return_to}}), do: return_to
  defp return_to(_params), do: ~p"/admin/users"
end
