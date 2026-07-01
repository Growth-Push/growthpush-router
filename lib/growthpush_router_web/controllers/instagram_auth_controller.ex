defmodule GrowthPushRouterWeb.InstagramAuthController do
  @moduledoc """
  Instagram OAuth endpoints for user-owned agent connections.

  The callback creates a connection record with an `access_token_ref` instead
  of persisting the raw Meta token in the connection row. A durable token vault
  can later bind that reference to the token without changing the connection
  ownership model.
  """

  use GrowthPushRouterWeb, :controller

  require Logger

  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents
  alias GrowthPushRouter.Agents.Agent

  @state_session_key :instagram_oauth_state
  @agent_session_key :instagram_oauth_agent_id
  @default_authorize_base_url "https://www.facebook.com"
  @default_graph_base_url "https://graph.facebook.com"
  @default_graph_version "v23.0"
  @default_scopes ~w(instagram_basic pages_show_list pages_read_engagement)

  def connect(conn, %{"agent_id" => agent_id}) do
    with {:ok, %Agent{} = _agent} <- fetch_connection_agent(conn, agent_id),
         {:ok, config} <- oauth_config(conn) do
      state = random_state()

      conn
      |> put_session(@state_session_key, state)
      |> put_session(@agent_session_key, agent_id)
      |> redirect(external: authorization_url(config, state))
    else
      {:error, :missing_config} ->
        conn
        |> put_flash(:error, gettext(".instagram_connect.missing_config"))
        |> redirect(to: ~p"/dashboard")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, gettext(".instagram_connect.agent_not_found"))
        |> redirect(to: ~p"/dashboard")
    end
  end

  def connect(conn, _params) do
    conn
    |> put_flash(:error, gettext(".instagram_connect.agent_not_found"))
    |> redirect(to: ~p"/dashboard")
  end

  def callback(conn, %{"error" => error}) do
    conn
    |> clear_oauth_session()
    |> put_flash(:error, gettext(".instagram_connect.denied", reason: error))
    |> redirect(to: ~p"/dashboard")
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    with :ok <- verify_state(conn, state),
         {:ok, agent_id} <- oauth_agent_id(conn),
         {:ok, %Agent{} = agent} <- fetch_connection_agent(conn, agent_id),
         {:ok, config} <- oauth_config(conn),
         {:ok, access_token} <- exchange_code(config, code),
         {:ok, account} <- fetch_instagram_account(config, access_token),
         {:ok, _connection} <- create_connection(conn, agent, account) do
      conn
      |> clear_oauth_session()
      |> put_flash(:info, gettext(".instagram_connect.connected"))
      |> redirect(to: ~p"/dashboard")
    else
      {:error, :invalid_state} ->
        conn
        |> clear_oauth_session()
        |> put_flash(:error, gettext(".instagram_connect.invalid_state"))
        |> redirect(to: ~p"/dashboard")

      {:error, :missing_config} ->
        conn
        |> clear_oauth_session()
        |> put_flash(:error, gettext(".instagram_connect.missing_config"))
        |> redirect(to: ~p"/dashboard")

      {:error, :unauthorized} ->
        conn
        |> clear_oauth_session()
        |> put_flash(:error, gettext(".instagram_connect.agent_not_found"))
        |> redirect(to: ~p"/dashboard")

      {:error, :instagram_account_not_found} ->
        log_oauth_failure(:instagram_account_not_found)

        conn
        |> clear_oauth_session()
        |> put_flash(:error, gettext(".instagram_connect.account_not_found"))
        |> redirect(to: ~p"/dashboard")

      {:error, {:token_exchange_failed, _status, _error} = reason} ->
        log_oauth_failure(reason)

        conn
        |> clear_oauth_session()
        |> put_flash(:error, gettext(".instagram_connect.token_exchange_failed"))
        |> redirect(to: ~p"/dashboard")

      {:error, {:instagram_account_fetch_failed, _status, _error} = reason} ->
        log_oauth_failure(reason)

        conn
        |> clear_oauth_session()
        |> put_flash(:error, gettext(".instagram_connect.account_fetch_failed"))
        |> redirect(to: ~p"/dashboard")

      {:error, %Ecto.Changeset{}} ->
        log_oauth_failure(:connection_changeset_failed)

        conn
        |> clear_oauth_session()
        |> put_flash(:error, gettext(".instagram_connect.connection_failed"))
        |> redirect(to: ~p"/dashboard")

      {:error, reason} ->
        log_oauth_failure(reason)

        conn
        |> clear_oauth_session()
        |> put_flash(:error, gettext(".instagram_connect.oauth_failed"))
        |> redirect(to: ~p"/dashboard")
    end
  end

  def callback(conn, _params) do
    conn
    |> clear_oauth_session()
    |> put_flash(:error, gettext(".instagram_connect.invalid_callback"))
    |> redirect(to: ~p"/dashboard")
  end

  defp fetch_connection_agent(%{assigns: %{current_user: %User{id: owner_id} = user}}, agent_id)
       when is_binary(owner_id) and is_binary(agent_id) do
    case Agents.list_agents(user, id: agent_id, owner_id: owner_id) do
      {:ok, [%Agent{} = agent]} -> {:ok, agent}
      {:ok, []} -> {:error, :unauthorized}
    end
  end

  defp fetch_connection_agent(_conn, _agent_id), do: {:error, :unauthorized}

  defp oauth_config(_conn) do
    config = Application.get_env(:growthpush_router, :instagram_oauth, [])

    with client_id when is_binary(client_id) and client_id != "" <- config[:client_id],
         client_secret when is_binary(client_secret) and client_secret != "" <-
           config[:client_secret] do
      {:ok,
       %{
         client_id: client_id,
         client_secret: client_secret,
         redirect_uri: config[:redirect_uri] || url(~p"/auth/instagram/callback"),
         authorize_base_url: config[:authorize_base_url] || @default_authorize_base_url,
         graph_base_url: config[:graph_base_url] || @default_graph_base_url,
         graph_version: config[:graph_version] || @default_graph_version,
         scopes: config[:scopes] || @default_scopes,
         req_options: config[:req_options] || []
       }}
    else
      _missing -> {:error, :missing_config}
    end
  end

  defp authorization_url(config, state) do
    query =
      URI.encode_query(%{
        client_id: config.client_id,
        redirect_uri: config.redirect_uri,
        response_type: "code",
        scope: Enum.join(config.scopes, ","),
        state: state
      })

    "#{config.authorize_base_url}/#{config.graph_version}/dialog/oauth?#{query}"
  end

  defp exchange_code(config, code) do
    config.req_options
    |> Keyword.merge(
      method: :get,
      url: "#{config.graph_base_url}/#{config.graph_version}/oauth/access_token",
      params: %{
        client_id: config.client_id,
        client_secret: config.client_secret,
        redirect_uri: config.redirect_uri,
        code: code
      },
      retry: false
    )
    |> Req.request()
    |> token_result()
  end

  defp token_result({:ok, %{status: status, body: body}}) do
    body = decode_response_body(body)

    case body do
      %{"access_token" => access_token} when status in 200..299 and is_binary(access_token) ->
        {:ok, access_token}

      _body ->
        {:error, {:token_exchange_failed, status, response_error(body)}}
    end
  end

  defp token_result({:error, reason}), do: {:error, reason}

  defp fetch_instagram_account(config, access_token) do
    config.req_options
    |> Keyword.merge(
      method: :get,
      url: "#{config.graph_base_url}/#{config.graph_version}/me/accounts",
      params: %{
        access_token: access_token,
        fields: "id,name,instagram_business_account{id,username,name}"
      },
      retry: false
    )
    |> Req.request()
    |> instagram_account_result()
  end

  defp instagram_account_result({:ok, %{status: status, body: body}}) do
    body = decode_response_body(body)

    case body do
      %{"data" => pages} when status in 200..299 and is_list(pages) ->
        pages
        |> Enum.find_value(&instagram_account/1)
        |> case do
          nil -> {:error, :instagram_account_not_found}
          account -> {:ok, account}
        end

      _body ->
        {:error, {:instagram_account_fetch_failed, status, response_error(body)}}
    end
  end

  defp instagram_account_result({:error, reason}), do: {:error, reason}

  defp decode_response_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded_body} -> decoded_body
      {:error, _error} -> body
    end
  end

  defp decode_response_body(body), do: body

  defp response_error(%{"error" => %{"message" => message, "code" => code} = error}) do
    %{
      code: code,
      message: message,
      type: error["type"],
      subcode: error["error_subcode"],
      trace_id: error["fbtrace_id"]
    }
  end

  defp response_error(%{"error" => error}), do: error
  defp response_error(body), do: body

  defp instagram_account(%{"instagram_business_account" => %{"id" => id} = account} = page)
       when is_binary(id) do
    %{
      id: id,
      display_name: account["username"] || account["name"] || page["name"] || id
    }
  end

  defp instagram_account(_page), do: nil

  defp create_connection(%{assigns: %{current_user: %User{} = user}}, %Agent{} = agent, account) do
    Agents.create_user_connection(user, %{
      "agent_id" => agent.id,
      "external_account_id" => account.id,
      "display_name" => account.display_name,
      "access_token_ref" => "oauth://meta/instagram/#{account.id}",
      "last_connected_at" => DateTime.utc_now(:second)
    })
  end

  defp verify_state(conn, state) when is_binary(state) do
    if get_session(conn, @state_session_key) == state do
      :ok
    else
      {:error, :invalid_state}
    end
  end

  defp verify_state(_conn, _state), do: {:error, :invalid_state}

  defp oauth_agent_id(conn) do
    case get_session(conn, @agent_session_key) do
      agent_id when is_binary(agent_id) -> {:ok, agent_id}
      _missing -> {:error, :invalid_state}
    end
  end

  defp clear_oauth_session(conn) do
    conn
    |> delete_session(@state_session_key)
    |> delete_session(@agent_session_key)
  end

  defp random_state do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp log_oauth_failure(reason) do
    Logger.warning("Instagram OAuth failed: #{inspect(reason)}")
  end
end
