defmodule GrowthPushRouterWeb.InstagramAuthControllerTest do
  use GrowthPushRouterWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents

  setup do
    original_oauth_config = Application.get_env(:growthpush_router, :instagram_oauth)

    on_exit(fn ->
      if is_nil(original_oauth_config) do
        Application.delete_env(:growthpush_router, :instagram_oauth)
      else
        Application.put_env(:growthpush_router, :instagram_oauth, original_oauth_config)
      end
    end)

    %{admin: %User{email: "admin@example.test"}}
  end

  test "routes require authentication", %{conn: conn} do
    for path <- [~p"/connect/instagram", ~p"/auth/instagram/callback"] do
      conn =
        conn
        |> recycle()
        |> get(path)

      assert redirected_to(conn) == ~p"/login"
    end
  end

  test "connect requires an agent id", %{conn: conn, admin: admin} do
    {_admin, user, _agent} = create_user_with_agent(admin, "instagram-missing-agent@example.com")

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/connect/instagram")

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "agent"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert get_session(conn, :instagram_oauth_agent_id) == nil
  end

  test "connect rejects agents owned by another user", %{conn: conn, admin: admin} do
    {_admin, user, _agent} = create_user_with_agent(admin, "instagram-owner@example.com")

    {_admin, _other_user, other_agent} =
      create_user_with_agent(admin, "instagram-other@example.com")

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/connect/instagram?agent_id=#{other_agent.id}")

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "agent"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert get_session(conn, :instagram_oauth_agent_id) == nil
  end

  test "connect requires OAuth config", %{conn: conn, admin: admin} do
    Application.delete_env(:growthpush_router, :instagram_oauth)
    {_admin, user, agent} = create_user_with_agent(admin, "instagram-missing-config@example.com")

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/connect/instagram?agent_id=#{agent.id}")

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "configurado"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert get_session(conn, :instagram_oauth_agent_id) == nil
  end

  test "connect redirects to Meta with state tied to the owned agent", %{conn: conn, admin: admin} do
    configure_instagram_oauth()
    {_admin, user, agent} = create_user_with_agent(admin, "instagram-connect@example.com")

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/connect/instagram?agent_id=#{agent.id}")

    location = redirected_to(conn, 302)
    uri = URI.parse(location)
    params = URI.decode_query(uri.query)

    assert uri.host == "www.facebook.com"
    assert uri.path == "/v23.0/dialog/oauth"
    assert params["client_id"] == "meta-client-id"
    assert params["redirect_uri"] == "http://www.example.com/auth/instagram/callback"
    assert params["response_type"] == "code"
    assert params["scope"] == "instagram_basic,pages_show_list,pages_read_engagement"
    assert params["state"] == get_session(conn, :instagram_oauth_state)
    assert byte_size(params["state"]) > 32
    assert get_session(conn, :instagram_oauth_agent_id) == agent.id
  end

  test "callback exchanges code, decodes string JSON, creates a connection, and clears session",
       %{conn: conn, admin: admin} do
    configure_instagram_oauth()
    stub_instagram_oauth_success()
    {_admin, user, agent} = create_user_with_agent(admin, "instagram-callback@example.com")

    conn = start_instagram_connect(conn, user, agent)
    state = get_session(conn, :instagram_oauth_state)

    conn =
      conn
      |> recycle()
      |> get(~p"/auth/instagram/callback?code=valid-code&state=#{state}")

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Instagram conectado"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert get_session(conn, :instagram_oauth_agent_id) == nil

    assert {:ok, [connection]} = Agents.list_connections(user, agent_id: agent.id)
    assert connection.provider == "meta"
    assert connection.channel == "instagram"
    assert connection.external_account_id == "17841400000000000"
    assert connection.display_name == "growthpush"
    assert connection.access_token_ref == "oauth://meta/instagram/17841400000000000"
    refute connection.access_token_ref =~ "meta-access-token"
    assert %DateTime{} = connection.last_connected_at
  end

  test "callback refreshes an existing owned connection for the same Instagram account",
       %{conn: conn, admin: admin} do
    configure_instagram_oauth()
    stub_instagram_oauth_success(%{"username" => "growthpush-updated"})
    {admin, user, agent} = create_user_with_agent(admin, "instagram-refresh@example.com")

    {:ok, existing_connection} =
      Agents.create_connection(admin, %{
        "agent_id" => agent.id,
        "connected_by_user_id" => user.id,
        "provider" => "meta",
        "channel" => "instagram",
        "external_account_id" => "17841400000000000",
        "display_name" => "old-growthpush",
        "access_token_ref" => "oauth://meta/instagram/old-growthpush"
      })

    conn = start_instagram_connect(conn, user, agent)
    state = get_session(conn, :instagram_oauth_state)

    conn =
      conn
      |> recycle()
      |> get(~p"/auth/instagram/callback?code=valid-code&state=#{state}")

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Instagram conectado"

    assert {:ok, [connection]} = Agents.list_connections(user, agent_id: agent.id)
    assert connection.id == existing_connection.id
    assert connection.display_name == "growthpush-updated"
    assert connection.access_token_ref == "oauth://meta/instagram/17841400000000000"
    assert %DateTime{} = connection.last_connected_at
  end

  test "callback falls back to account name when Meta omits username", %{conn: conn, admin: admin} do
    configure_instagram_oauth()
    stub_instagram_oauth_success(%{"username" => nil, "name" => "Growth Push IG"})
    {_admin, user, agent} = create_user_with_agent(admin, "instagram-name-fallback@example.com")

    conn = start_instagram_connect(conn, user, agent)
    state = get_session(conn, :instagram_oauth_state)

    conn =
      conn
      |> recycle()
      |> get(~p"/auth/instagram/callback?code=valid-code&state=#{state}")

    assert redirected_to(conn) == ~p"/dashboard"

    assert {:ok, [connection]} = Agents.list_connections(user, agent_id: agent.id)
    assert connection.display_name == "Growth Push IG"
  end

  test "callback clears session when Meta returns a denial", %{conn: conn, admin: admin} do
    configure_instagram_oauth()
    {_admin, user, agent} = create_user_with_agent(admin, "instagram-denied@example.com")

    conn = start_instagram_connect(conn, user, agent)

    conn =
      conn
      |> recycle()
      |> get(~p"/auth/instagram/callback?error=access_denied")

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "cancelada"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert get_session(conn, :instagram_oauth_agent_id) == nil
  end

  test "callback rejects invalid state and clears the OAuth session", %{conn: conn, admin: admin} do
    configure_instagram_oauth()
    {_admin, user, agent} = create_user_with_agent(admin, "instagram-invalid-state@example.com")

    conn = start_instagram_connect(conn, user, agent)

    conn =
      conn
      |> recycle()
      |> get(~p"/auth/instagram/callback?code=valid-code&state=wrong")

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "estado"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert get_session(conn, :instagram_oauth_agent_id) == nil
    assert {:ok, []} = Agents.list_connections(user, agent_id: agent.id)
  end

  test "callback rejects missing code or state params and clears the OAuth session",
       %{conn: conn, admin: admin} do
    configure_instagram_oauth()

    {_admin, user, agent} =
      create_user_with_agent(admin, "instagram-invalid-callback@example.com")

    conn = start_instagram_connect(conn, user, agent)

    conn =
      conn
      |> recycle()
      |> get(~p"/auth/instagram/callback")

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "inválido"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert get_session(conn, :instagram_oauth_agent_id) == nil
    assert {:ok, []} = Agents.list_connections(user, agent_id: agent.id)
  end

  test "callback rejects a missing agent session even when state matches", %{
    conn: conn,
    admin: admin
  } do
    configure_instagram_oauth()

    {_admin, user, _agent} =
      create_user_with_agent(admin, "instagram-missing-agent-session@example.com")

    conn =
      conn
      |> log_in_user(user)
      |> put_session(:instagram_oauth_state, "state-without-agent")
      |> get(~p"/auth/instagram/callback?code=valid-code&state=state-without-agent")

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "estado"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert get_session(conn, :instagram_oauth_agent_id) == nil
  end

  test "callback reports Meta token exchange errors", %{conn: conn, admin: admin} do
    configure_instagram_oauth()
    stub_instagram_oauth_token_error()
    {_admin, user, agent} = create_user_with_agent(admin, "instagram-token-error@example.com")

    conn = start_instagram_connect(conn, user, agent)
    state = get_session(conn, :instagram_oauth_state)

    {conn, log} =
      with_log(fn ->
        conn
        |> recycle()
        |> get(~p"/auth/instagram/callback?code=bad-code&state=#{state}")
      end)

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "trocar o código OAuth"
    assert log =~ "Instagram OAuth failed"
    assert log =~ "Invalid OAuth access token"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert {:ok, []} = Agents.list_connections(user, agent_id: agent.id)
  end

  test "callback reports Meta account fetch errors", %{conn: conn, admin: admin} do
    configure_instagram_oauth()
    stub_instagram_oauth_account_error()
    {_admin, user, agent} = create_user_with_agent(admin, "instagram-account-error@example.com")

    conn = start_instagram_connect(conn, user, agent)
    state = get_session(conn, :instagram_oauth_state)

    {conn, log} =
      with_log(fn ->
        conn
        |> recycle()
        |> get(~p"/auth/instagram/callback?code=valid-code&state=#{state}")
      end)

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "buscar a conta Instagram"
    assert log =~ "Missing permissions"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert {:ok, []} = Agents.list_connections(user, agent_id: agent.id)
  end

  test "callback reports when Meta returns pages without an Instagram business account",
       %{conn: conn, admin: admin} do
    configure_instagram_oauth()

    stub_instagram_oauth_accounts(%{
      "data" => [%{"id" => "page-id", "name" => "Growth Push Page"}]
    })

    {_admin, user, agent} =
      create_user_with_agent(admin, "instagram-no-business-account@example.com")

    conn = start_instagram_connect(conn, user, agent)
    state = get_session(conn, :instagram_oauth_state)

    {conn, log} =
      with_log(fn ->
        conn
        |> recycle()
        |> get(~p"/auth/instagram/callback?code=valid-code&state=#{state}")
      end)

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "conta Instagram"
    assert log =~ "instagram_account_not_found"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert {:ok, []} = Agents.list_connections(user, agent_id: agent.id)
  end

  test "callback reports connection persistence errors without leaking a partial connection",
       %{conn: conn, admin: admin} do
    configure_instagram_oauth()

    stub_instagram_oauth_success(%{
      "id" => String.duplicate("1", 300),
      "username" => "external-id-too-long"
    })

    {_admin, user, agent} =
      create_user_with_agent(admin, "instagram-connection-error@example.com")

    conn = start_instagram_connect(conn, user, agent)
    state = get_session(conn, :instagram_oauth_state)

    {conn, log} =
      with_log(fn ->
        conn
        |> recycle()
        |> get(~p"/auth/instagram/callback?code=valid-code&state=#{state}")
      end)

    assert redirected_to(conn) == ~p"/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "salvar a conexão"
    assert log =~ "connection_changeset_failed"
    assert get_session(conn, :instagram_oauth_state) == nil
    assert {:ok, []} = Agents.list_connections(user, agent_id: agent.id)
  end

  defp log_in_user(conn, %User{} = user) do
    Plug.Test.init_test_session(conn, user_id: user.id, live_socket_id: live_socket_id(user))
  end

  defp start_instagram_connect(conn, %User{} = user, agent) do
    conn
    |> log_in_user(user)
    |> get(~p"/connect/instagram?agent_id=#{agent.id}")
  end

  defp create_user_with_agent(%User{} = admin, email) do
    admin = User.with_runtime_role(admin)

    {:ok, user} =
      Accounts.create_user(admin, %{
        "email" => email,
        "name" => "Instagram User"
      })

    {:ok, agent} =
      Agents.create_agent(admin, %{
        "owner_id" => user.id,
        "slug" => email |> String.split("@") |> List.first(),
        "endpoint_url" => "https://agent.example.test/events",
        "shared_secret" => "agent-secret-1234"
      })

    {admin, user, agent}
  end

  defp configure_instagram_oauth do
    Application.put_env(:growthpush_router, :instagram_oauth,
      client_id: "meta-client-id",
      client_secret: "meta-client-secret",
      redirect_uri: "http://www.example.com/auth/instagram/callback",
      authorize_base_url: "https://www.facebook.com",
      graph_base_url: "https://graph.facebook.com",
      graph_version: "v23.0",
      scopes: ~w(instagram_basic pages_show_list pages_read_engagement),
      req_options: [plug: {Req.Test, GrowthPushRouter.InstagramOAuth}]
    )
  end

  defp stub_instagram_oauth_success(account_attrs \\ %{}) do
    account =
      %{
        "id" => "17841400000000000",
        "username" => "growthpush",
        "name" => "Growth Push"
      }
      |> Map.merge(account_attrs)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    stub_instagram_oauth_accounts(%{
      "data" => [
        %{
          "id" => "page-id",
          "name" => "Growth Push Page",
          "instagram_business_account" => account
        }
      ]
    })
  end

  defp stub_instagram_oauth_accounts(accounts_body) do
    Req.Test.stub(GrowthPushRouter.InstagramOAuth, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.request_path do
        "/v23.0/oauth/access_token" ->
          assert conn.query_params["client_id"] == "meta-client-id"
          assert conn.query_params["client_secret"] == "meta-client-secret"

          assert conn.query_params["redirect_uri"] ==
                   "http://www.example.com/auth/instagram/callback"

          assert conn.query_params["code"] in ["valid-code", "bad-code"]

          Req.Test.json(conn, %{"access_token" => "meta-access-token"})

        "/v23.0/me/accounts" ->
          assert conn.query_params["access_token"] == "meta-access-token"

          Req.Test.text(conn, Jason.encode!(accounts_body))
      end
    end)
  end

  defp stub_instagram_oauth_token_error do
    Req.Test.stub(GrowthPushRouter.InstagramOAuth, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.request_path == "/v23.0/oauth/access_token"
      assert conn.query_params["code"] == "bad-code"

      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{
        "error" => %{
          "message" => "Invalid OAuth access token",
          "type" => "OAuthException",
          "code" => 190,
          "fbtrace_id" => "token-trace"
        }
      })
    end)
  end

  defp stub_instagram_oauth_account_error do
    Req.Test.stub(GrowthPushRouter.InstagramOAuth, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.request_path do
        "/v23.0/oauth/access_token" ->
          Req.Test.json(conn, %{"access_token" => "meta-access-token"})

        "/v23.0/me/accounts" ->
          conn
          |> Plug.Conn.put_status(403)
          |> Req.Test.text(
            Jason.encode!(%{
              "error" => %{
                "message" => "Missing permissions",
                "type" => "OAuthException",
                "code" => 10,
                "fbtrace_id" => "account-trace"
              }
            })
          )
      end
    end)
  end

  defp live_socket_id(%User{id: id}), do: "users_sessions:#{Base.url_encode64(id)}"
end
