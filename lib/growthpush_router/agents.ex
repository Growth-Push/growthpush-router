defmodule GrowthPushRouter.Agents do
  @moduledoc """
  Domain context for router-agent installations.
  """

  import Ecto.Query, warn: false

  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents.Agent
  alias GrowthPushRouter.Agents.Connection
  alias GrowthPushRouter.Agents.Event
  alias GrowthPushRouter.Repo

  @doc """
  Lists agents visible to an actor.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "agents-list-doc@example.com", "name" => "Agents List Doc"})
      iex> {:ok, _agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "agents-list-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, agents} = Agents.list_agents(admin, slug: "agents-list-doc")
      iex> Enum.map(agents, & &1.slug)
      ["agents-list-doc"]

  """
  def list_agents(actor_user, opts \\ [])

  def list_agents(%User{is_admin: true}, opts) do
    {:ok, do_list_agents(opts)}
  end

  def list_agents(%User{id: owner_id}, opts) when is_binary(owner_id) do
    agents =
      opts
      |> force_owner_filter(owner_id)
      |> do_list_agents()

    {:ok, agents}
  end

  def list_agents(_actor_user, _opts), do: {:error, :unauthorized}

  @doc """
  Fetches an agent for an admin or owner actor.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "agents-fetch-doc@example.com", "name" => "Agents Fetch Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "agents-fetch-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, fetched_agent} = Agents.fetch_agent(owner, agent.id)
      iex> fetched_agent.slug
      "agents-fetch-doc"

  """
  def fetch_agent(%User{is_admin: true}, id) do
    {:ok, Repo.get!(Agent, id)}
  end

  def fetch_agent(%User{} = actor_user, id) when is_binary(id) do
    case list_agents(actor_user, id: id) do
      {:ok, [%Agent{} = agent]} -> {:ok, agent}
      {:ok, []} -> {:error, :unauthorized}
      {:error, :unauthorized} -> {:error, :unauthorized}
    end
  end

  def fetch_agent(_actor_user, _id), do: {:error, :unauthorized}

  @doc """
  Creates an agent as an admin operation.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "agents-create-doc@example.com", "name" => "Agents Create Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "agents-create-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> agent.status
      "inactive"

  """
  def create_agent(%User{is_admin: true}, attrs) do
    do_create_agent(attrs)
  end

  def create_agent(_admin_user, _attrs), do: {:error, :unauthorized}

  @doc """
  Updates an agent as an admin operation.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "agents-update-doc@example.com", "name" => "Agents Update Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "agents-update-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, updated_agent} = Agents.update_agent(admin, agent, %{"status" => "active"})
      iex> updated_agent.status
      "active"

  """
  def update_agent(%User{is_admin: true}, %Agent{} = agent, attrs) do
    do_update_agent(agent, attrs)
  end

  def update_agent(_admin_user, _agent, _attrs), do: {:error, :unauthorized}

  @doc """
  Deletes an agent as an admin operation.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "agents-delete-doc@example.com", "name" => "Agents Delete Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "agents-delete-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, deleted_agent} = Agents.delete_agent(admin, agent)
      iex> deleted_agent.slug
      "agents-delete-doc"

  """
  def delete_agent(%User{is_admin: true}, %Agent{} = agent) do
    Repo.delete(agent)
  end

  def delete_agent(_admin_user, _agent), do: {:error, :unauthorized}

  @doc """
  Returns an agent changeset.

  ## Examples

      iex> alias GrowthPushRouter.Agents
      iex> alias GrowthPushRouter.Agents.Agent
      iex> changeset =
      ...>   Agents.change_agent(%Agent{}, %{
      ...>     "owner_id" => Ecto.UUID.generate(),
      ...>     "slug" => "change-agent-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> changeset.valid?
      true

  """
  def change_agent(%Agent{} = agent, attrs \\ %{}) do
    Agent.admin_changeset(agent, attrs)
  end

  @doc """
  Lists connected channels visible to an actor.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "connections-list-doc@example.com", "name" => "Connections List Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "connections-list-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, _connection} =
      ...>   Agents.create_connection(admin, %{
      ...>     "agent_id" => agent.id,
      ...>     "connected_by_user_id" => owner.id,
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "connections-list-doc-account",
      ...>     "display_name" => "Connections List Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/connections-list-doc"
      ...>   })
      iex> {:ok, connections} = Agents.list_connections(admin, agent_id: agent.id)
      iex> Enum.map(connections, & &1.display_name)
      ["Connections List Doc"]
      iex> {:ok, owner_connections} = Agents.list_connections(owner)
      iex> Enum.map(owner_connections, & &1.display_name)
      ["Connections List Doc"]

  """
  def list_connections(actor_user, opts \\ [])

  def list_connections(%User{is_admin: true}, opts) do
    {:ok, do_list_connections(opts)}
  end

  def list_connections(%User{id: owner_id}, opts) when is_binary(owner_id) do
    {:ok, do_list_connections(opts, owner_id)}
  end

  def list_connections(_actor_user, _opts), do: {:error, :unauthorized}

  @doc """
  Fetches a connection visible to an actor.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "connections-fetch-doc@example.com", "name" => "Connections Fetch Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "connections-fetch-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, connection} =
      ...>   Agents.create_connection(admin, %{
      ...>     "agent_id" => agent.id,
      ...>     "connected_by_user_id" => owner.id,
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "connections-fetch-doc-account",
      ...>     "display_name" => "Connections Fetch Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/connections-fetch-doc"
      ...>   })
      iex> {:ok, fetched_connection} = Agents.fetch_connection(owner, connection.id)
      iex> fetched_connection.display_name
      "Connections Fetch Doc"

  """
  def fetch_connection(%User{} = actor_user, id) when is_binary(id) do
    case list_connections(actor_user, id: id) do
      {:ok, [%Connection{} = connection]} -> {:ok, connection}
      {:ok, []} -> {:error, :unauthorized}
      {:error, :unauthorized} -> {:error, :unauthorized}
    end
  end

  def fetch_connection(_actor_user, _id), do: {:error, :unauthorized}

  @doc """
  Fetches a provider connection by external account id for system ingestion.

  This lookup is used by trusted webhook ingestion paths that receive provider
  events before there is an authenticated user actor.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "connections-provider-fetch-doc@example.com", "name" => "Connections Provider Fetch Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "connections-provider-fetch-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, connection} =
      ...>   Agents.create_connection(admin, %{
      ...>     "agent_id" => agent.id,
      ...>     "connected_by_user_id" => owner.id,
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "provider-fetch-doc-account",
      ...>     "display_name" => "Connections Provider Fetch Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/provider-fetch-doc"
      ...>   })
      iex> {:ok, fetched_connection} = Agents.fetch_provider_connection(" Meta ", " Instagram ", "provider-fetch-doc-account")
      iex> {fetched_connection.id, fetched_connection.agent.id} == {connection.id, agent.id}
      true

  """
  def fetch_provider_connection(provider, channel, external_account_id)
      when is_binary(provider) and is_binary(channel) and is_binary(external_account_id) do
    query =
      Connection
      |> filter_connection_query(provider: provider)
      |> filter_connection_query(channel: channel)
      |> filter_connection_query(external_account_id: external_account_id)
      |> preload(:agent)

    case Repo.one(query) do
      %Connection{} = connection -> {:ok, connection}
      nil -> {:error, :not_found}
    end
  end

  def fetch_provider_connection(_provider, _channel, _external_account_id),
    do: {:error, :not_found}

  @doc """
  Creates a connected channel as an admin operation.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "connections-create-doc@example.com", "name" => "Connections Create Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "connections-create-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, connection} =
      ...>   Agents.create_connection(admin, %{
      ...>     "agent_id" => agent.id,
      ...>     "connected_by_user_id" => owner.id,
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "connections-create-doc-account",
      ...>     "display_name" => "Connections Create Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/connections-create-doc"
      ...>   })
      iex> connection.status
      "active"

  """
  def create_connection(%User{is_admin: true}, attrs) do
    do_create_connection(attrs)
  end

  def create_connection(_admin_user, _attrs), do: {:error, :unauthorized}

  @doc """
  Deletes a connection as the owning user or as an admin.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "connections-delete-doc@example.com", "name" => "Connections Delete Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "connections-delete-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, connection} =
      ...>   Agents.create_connection(admin, %{
      ...>     "agent_id" => agent.id,
      ...>     "connected_by_user_id" => owner.id,
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "connections-delete-doc-account",
      ...>     "display_name" => "Connections Delete Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/connections-delete-doc"
      ...>   })
      iex> {:ok, deleted_connection} = Agents.delete_connection(owner, connection)
      iex> deleted_connection.display_name
      "Connections Delete Doc"

  """
  def delete_connection(%User{} = actor_user, %Connection{id: id}) when is_binary(id) do
    with {:ok, %Connection{} = connection} <- fetch_connection(actor_user, id) do
      Repo.delete(connection)
    end
  end

  def delete_connection(_actor_user, _connection), do: {:error, :unauthorized}

  @doc """
  Creates a manual Meta Instagram connection for an agent owned by the actor.

  User-controlled attrs are limited to the agent id, external account id,
  display name, and token reference. Provider, channel, status, and connected
  user are derived by the context.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "connections-user-create-doc@example.com", "name" => "Connections User Create Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "connections-user-create-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, connection} =
      ...>   Agents.create_user_connection(owner, %{
      ...>     "agent_id" => agent.id,
      ...>     "external_account_id" => "connections-user-create-doc-account",
      ...>     "display_name" => "Connections User Create Doc",
      ...>     "access_token_ref" => "placeholder://meta/instagram/connections-user-create-doc"
      ...>   })
      iex> {connection.provider, connection.channel, connection.connected_by_user_id}
      {"meta", "instagram", owner.id}

  """
  def create_user_connection(%User{id: user_id} = actor_user, %{"agent_id" => agent_id} = attrs)
      when is_binary(user_id) and is_binary(agent_id) do
    with {:ok, %Agent{} = agent} <- fetch_connection_agent(actor_user, agent_id) do
      attrs
      |> user_connection_attrs(actor_user, agent)
      |> do_create_or_refresh_user_connection(actor_user)
    end
  end

  def create_user_connection(%User{} = actor_user, %{agent_id: agent_id} = attrs)
      when is_binary(agent_id) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("agent_id", agent_id)

    create_user_connection(actor_user, attrs)
  end

  def create_user_connection(_actor_user, _attrs), do: {:error, :unauthorized}

  @doc """
  Returns a connection changeset.

  ## Examples

      iex> alias GrowthPushRouter.Agents
      iex> alias GrowthPushRouter.Agents.Connection
      iex> changeset =
      ...>   Agents.change_connection(%Connection{}, %{
      ...>     "agent_id" => Ecto.UUID.generate(),
      ...>     "connected_by_user_id" => Ecto.UUID.generate(),
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "change-connection-doc-account",
      ...>     "display_name" => "Change Connection Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/change-connection-doc"
      ...>   })
      iex> changeset.valid?
      true

  """
  def change_connection(%Connection{} = connection, attrs \\ %{}) do
    Connection.admin_changeset(connection, attrs)
  end

  @doc """
  Creates a raw event received through a connection.

  The connection must belong to the acting agent. The connection id, provider,
  and channel are loaded from the database instead of trusting inbound event
  attributes.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "events-create-doc@example.com", "name" => "Events Create Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "events-create-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, connection} =
      ...>   Agents.create_connection(admin, %{
      ...>     "agent_id" => agent.id,
      ...>     "connected_by_user_id" => owner.id,
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "events-create-doc-account",
      ...>     "display_name" => "Events Create Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/events-create-doc"
      ...>   })
      iex> {:ok, event} =
      ...>   Agents.create_connection_event(agent, connection, %{
      ...>     "event_type" => "message_received",
      ...>     "external_event_id" => "evt-create-doc",
      ...>     "payload" => %{"entry" => [%{"id" => "17841400000000000"}]}
      ...>   })
      iex> {event.connection_id, event.provider, event.channel, event.status, event.stored_by}
      {connection.id, "meta", "instagram", "received", "edge"}

  """
  def create_connection_event(%Agent{} = agent, %Connection{id: connection_id}, attrs) do
    create_connection_event(agent, connection_id, attrs)
  end

  def create_connection_event(%Agent{} = agent, connection_id, attrs)
      when is_binary(connection_id) and is_map(attrs) do
    do_create_connection_event(agent, connection_id, attrs, "edge")
  end

  def create_connection_event(_agent, _connection, _attrs), do: {:error, :unauthorized}

  @doc """
  Creates an agent-side event available to local consumers.

  The event is persisted with `stored_by` set to `"agent"` and can be consumed
  by local programs with `list_agent_events_after/3`.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "agent-events-create-doc@example.com", "name" => "Agent Events Create Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "agent-events-create-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, connection} =
      ...>   Agents.create_connection(admin, %{
      ...>     "agent_id" => agent.id,
      ...>     "connected_by_user_id" => owner.id,
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "agent-events-create-doc-account",
      ...>     "display_name" => "Agent Events Create Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/agent-events-create-doc"
      ...>   })
      iex> {:ok, event} =
      ...>   Agents.create_agent_event(agent, connection, %{
      ...>     "event_type" => "message_received",
      ...>     "payload" => %{"entry" => []}
      ...>   })
      iex> event.stored_by
      "agent"

  """
  def create_agent_event(%Agent{} = agent, %Connection{id: connection_id}, attrs) do
    create_agent_event(agent, connection_id, attrs)
  end

  def create_agent_event(%Agent{} = agent, connection_id, attrs)
      when is_binary(connection_id) and is_map(attrs) do
    do_create_connection_event(agent, connection_id, attrs, "agent")
  end

  def create_agent_event(_agent, _connection, _attrs), do: {:error, :unauthorized}

  @doc """
  Marks an edge-stored event as synced after the local agent accepted it.

  Only the agent that owns the event connection can mark the event synced.
  Agent-stored events are internal consumer records and are not updated by this
  operation.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "events-sync-doc@example.com", "name" => "Events Sync Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "events-sync-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, connection} =
      ...>   Agents.create_connection(admin, %{
      ...>     "agent_id" => agent.id,
      ...>     "connected_by_user_id" => owner.id,
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "events-sync-doc-account",
      ...>     "display_name" => "Events Sync Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/events-sync-doc"
      ...>   })
      iex> {:ok, event} = Agents.create_connection_event(agent, connection, %{"event_type" => "message_received"})
      iex> {:ok, synced_event} = Agents.mark_event_synced(agent, event)
      iex> synced_event.status
      "synced"

  """
  def mark_event_synced(%Agent{} = agent, %Event{id: event_id}) when is_binary(event_id) do
    mark_event_synced(agent, event_id)
  end

  def mark_event_synced(%Agent{} = agent, event_id) when is_binary(event_id) do
    with {:ok, %Event{} = event} <- fetch_agent_edge_event(agent, event_id) do
      event
      |> Event.changeset(%{
        "status" => "synced",
        "processed_at" => DateTime.utc_now(:second)
      })
      |> Repo.update()
    end
  end

  def mark_event_synced(_agent, _event), do: {:error, :unauthorized}

  defp do_create_connection_event(%Agent{} = agent, connection_id, attrs, stored_by) do
    with {:ok, %Connection{} = connection} <- fetch_event_connection(agent, connection_id) do
      attrs
      |> stringify_keys()
      |> connection_event_attrs(connection, stored_by)
      |> do_create_event()
    end
  end

  @doc """
  Lists edge-stored connection events visible to an actor.

  Agent-stored events are internal consumer records and are intentionally not
  returned by this generic read API. Local consumers should use
  `list_agent_events_after/3`.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "events-list-doc@example.com", "name" => "Events List Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "events-list-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, connection} =
      ...>   Agents.create_connection(admin, %{
      ...>     "agent_id" => agent.id,
      ...>     "connected_by_user_id" => owner.id,
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "events-list-doc-account",
      ...>     "display_name" => "Events List Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/events-list-doc"
      ...>   })
      iex> {:ok, _event} =
      ...>   Agents.create_connection_event(agent, connection, %{
      ...>     "event_type" => "message_received",
      ...>     "payload" => %{"entry" => []}
      ...>   })
      iex> {:ok, events} = Agents.list_events(agent, event_type: "Message_Received")
      iex> Enum.map(events, & &1.event_type)
      ["message_received"]
      iex> {:ok, owner_events} = Agents.list_events(owner, event_type: "Message_Received")
      iex> Enum.map(owner_events, & &1.event_type)
      ["message_received"]

  """
  def list_events(actor, opts \\ [])

  def list_events(%User{is_admin: true}, opts) do
    {:ok, do_list_events(edge_event_opts(opts))}
  end

  def list_events(%User{id: owner_id}, opts) when is_binary(owner_id) do
    {:ok, do_list_events_for_owner(edge_event_opts(opts), owner_id)}
  end

  def list_events(%Agent{id: agent_id}, opts) when is_binary(agent_id) do
    {:ok, do_list_events_for_agent(edge_event_opts(opts), agent_id)}
  end

  def list_events(_actor, _opts), do: {:error, :unauthorized}

  @doc """
  Lists agent-side events after a sequence cursor.

  This is the DB-backed consumption API for local programs. Consumers should
  store their own last processed sequence and call this function again with
  that value.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "agent-events-list-doc@example.com", "name" => "Agent Events List Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "agent-events-list-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, connection} =
      ...>   Agents.create_connection(admin, %{
      ...>     "agent_id" => agent.id,
      ...>     "connected_by_user_id" => owner.id,
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "agent-events-list-doc-account",
      ...>     "display_name" => "Agent Events List Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/agent-events-list-doc"
      ...>   })
      iex> {:ok, event} = Agents.create_agent_event(agent, connection, %{"event_type" => "message_received"})
      iex> {:ok, events} = Agents.list_agent_events_after(agent, event.sequence - 1)
      iex> Enum.map(events, & &1.id)
      [event.id]

  """
  def list_agent_events_after(actor, sequence, opts \\ [])

  def list_agent_events_after(%Agent{id: agent_id}, sequence, opts)
      when is_binary(agent_id) and is_integer(sequence) do
    limit = event_consumer_limit(opts)

    events =
      Event
      |> join(:inner, [e], c in assoc(e, :connection))
      |> where([e, c], c.agent_id == ^agent_id)
      |> where([e, _c], e.stored_by == "agent")
      |> where([e, _c], e.sequence > ^sequence)
      |> order_by([e, _c], asc: e.sequence)
      |> limit(^limit)
      |> Repo.all()

    {:ok, events}
  end

  def list_agent_events_after(_actor, _sequence, _opts), do: {:error, :unauthorized}

  @doc """
  Fetches a connection event visible to an actor.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = User.with_runtime_role(%User{email: "admin@example.test"})
      iex> {:ok, owner} = Accounts.create_user(admin, %{"email" => "events-fetch-doc@example.com", "name" => "Events Fetch Doc"})
      iex> {:ok, agent} =
      ...>   Agents.create_agent(admin, %{
      ...>     "owner_id" => owner.id,
      ...>     "slug" => "events-fetch-doc",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> {:ok, connection} =
      ...>   Agents.create_connection(admin, %{
      ...>     "agent_id" => agent.id,
      ...>     "connected_by_user_id" => owner.id,
      ...>     "provider" => "meta",
      ...>     "channel" => "instagram",
      ...>     "external_account_id" => "events-fetch-doc-account",
      ...>     "display_name" => "Events Fetch Doc",
      ...>     "access_token_ref" => "vault://meta/instagram/events-fetch-doc"
      ...>   })
      iex> {:ok, event} =
      ...>   Agents.create_connection_event(agent, connection, %{
      ...>     "event_type" => "message_received",
      ...>     "payload" => %{"entry" => []}
      ...>   })
      iex> {:ok, fetched_event} = Agents.fetch_event(owner, event.id)
      iex> fetched_event.id == event.id
      true

  """
  def fetch_event(actor, id) when is_binary(id) do
    case list_events(actor, id: id) do
      {:ok, [%Event{} = event]} -> {:ok, event}
      {:ok, []} -> {:error, :unauthorized}
      {:error, :unauthorized} -> {:error, :unauthorized}
    end
  end

  def fetch_event(_actor, _id), do: {:error, :unauthorized}

  defp do_list_agents(opts) do
    query = from(a in Agent)

    opts
    |> Enum.reduce(query, fn filter, q ->
      filter_agent_query(q, [filter])
    end)
    |> order_by([a], asc: a.inserted_at)
    |> Repo.all()
  end

  defp do_list_connections(opts) do
    query = from(c in Connection, join: a in assoc(c, :agent))

    opts
    |> Enum.reduce(query, fn filter, q ->
      filter_connection_query(q, [filter])
    end)
    |> order_by([c, _a], asc: c.inserted_at)
    |> Repo.all()
  end

  defp do_list_connections(opts, owner_id) do
    opts
    |> do_list_connections_query()
    |> where([_c, a], a.owner_id == ^owner_id)
    |> order_by([c, _a], asc: c.inserted_at)
    |> Repo.all()
  end

  defp do_list_connections_query(opts) do
    query = from(c in Connection, join: a in assoc(c, :agent))

    Enum.reduce(opts, query, fn filter, q ->
      filter_connection_query(q, [filter])
    end)
  end

  defp do_list_events(opts) do
    opts
    |> do_list_events_query()
    |> order_events()
    |> Repo.all()
  end

  defp do_list_events_for_owner(opts, owner_id) do
    opts
    |> do_list_events_query()
    |> where([_e, _c, a], a.owner_id == ^owner_id)
    |> order_events()
    |> Repo.all()
  end

  defp do_list_events_for_agent(opts, agent_id) do
    opts
    |> do_list_events_query()
    |> where([_e, c, _a], c.agent_id == ^agent_id)
    |> order_events()
    |> Repo.all()
  end

  defp order_events(query) do
    order_by(query, [e, _c, _a], desc: e.received_at, desc: e.inserted_at)
  end

  defp do_list_events_query(opts) do
    query = from(e in Event, join: c in assoc(e, :connection), join: a in assoc(c, :agent))

    Enum.reduce(opts, query, fn filter, q ->
      filter_event_query(q, [filter])
    end)
  end

  defp edge_event_opts(opts) when is_list(opts) do
    stored_by = Keyword.get(opts, :stored_by)

    opts
    |> Keyword.delete(:stored_by)
    |> Keyword.put(:stored_by, edge_event_storage_filter(stored_by))
  end

  defp edge_event_opts(_opts), do: [stored_by: "edge"]

  defp edge_event_storage_filter(nil), do: "edge"

  defp edge_event_storage_filter(stored_by) when is_binary(stored_by) do
    if GrowthPushRouter.Helpers.normalize_string(stored_by) == "edge" do
      "edge"
    else
      "__hidden_agent_events__"
    end
  end

  defp edge_event_storage_filter(_stored_by), do: "__hidden_agent_events__"

  defp event_consumer_limit(opts) do
    opts
    |> Keyword.get(:limit, 100)
    |> clamp_event_consumer_limit()
  end

  defp clamp_event_consumer_limit(limit) when is_integer(limit) and limit in 1..500, do: limit
  defp clamp_event_consumer_limit(limit) when is_integer(limit) and limit > 500, do: 500
  defp clamp_event_consumer_limit(_limit), do: 100

  defp do_create_agent(attrs) do
    %Agent{}
    |> Agent.admin_changeset(attrs)
    |> Repo.insert()
  end

  defp do_create_connection(attrs) do
    %Connection{}
    |> Connection.admin_changeset(attrs)
    |> Repo.insert()
  end

  defp do_create_event(attrs) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  defp do_create_or_refresh_user_connection(attrs, %User{} = actor_user) do
    case do_create_connection(attrs) do
      {:ok, %Connection{} = connection} ->
        {:ok, connection}

      {:error, %Ecto.Changeset{} = changeset} ->
        maybe_refresh_existing_user_connection(changeset, attrs, actor_user)
    end
  end

  defp maybe_refresh_existing_user_connection(changeset, attrs, %User{} = actor_user) do
    if unique_external_account_error?(changeset) do
      refresh_existing_user_connection(attrs, actor_user)
    else
      {:error, changeset}
    end
  end

  defp unique_external_account_error?(%Ecto.Changeset{} = changeset) do
    Enum.any?(changeset.errors, fn
      {:external_account_id, {_message, opts}} ->
        opts[:constraint] == :unique and
          opts[:constraint_name] == "connections_provider_channel_external_account_id_index"

      _error ->
        false
    end)
  end

  defp refresh_existing_user_connection(attrs, %User{} = actor_user) do
    case list_connections(actor_user,
           provider: attrs["provider"],
           channel: attrs["channel"],
           external_account_id: attrs["external_account_id"]
         ) do
      {:ok, [%Connection{} = connection]} ->
        connection
        |> Connection.admin_changeset(attrs)
        |> Repo.update()

      {:ok, []} ->
        {:error, :unauthorized}

      {:error, :unauthorized} ->
        {:error, :unauthorized}
    end
  end

  defp do_update_agent(%Agent{} = agent, attrs) do
    agent
    |> Agent.admin_changeset(attrs)
    |> Repo.update()
  end

  defp filter_agent_query(query, owner_id: owner_id) when is_binary(owner_id) do
    where(query, [a], a.owner_id == ^owner_id)
  end

  defp filter_agent_query(query, id: id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> where(query, [a], a.id == ^id)
      :error -> where(query, false)
    end
  end

  defp filter_agent_query(query, slug: slug) when is_binary(slug) do
    where(query, [a], a.slug == ^GrowthPushRouter.Helpers.normalize_string(slug))
  end

  defp filter_agent_query(query, status: status) when is_binary(status) do
    where(query, [a], a.status == ^status)
  end

  defp filter_agent_query(query, _), do: query

  defp filter_connection_query(query, agent_id: agent_id) when is_binary(agent_id) do
    where(query, [c, _a], c.agent_id == ^agent_id)
  end

  defp filter_connection_query(query, id: id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> where(query, [c, _a], c.id == ^id)
      :error -> where(query, false)
    end
  end

  defp filter_connection_query(query, connected_by_user_id: connected_by_user_id)
       when is_binary(connected_by_user_id) do
    where(query, [c, _a], c.connected_by_user_id == ^connected_by_user_id)
  end

  defp filter_connection_query(query, external_account_id: external_account_id)
       when is_binary(external_account_id) do
    where(query, [c, _a], c.external_account_id == ^external_account_id)
  end

  defp filter_connection_query(query, provider: provider) when is_binary(provider) do
    where(query, [c, _a], c.provider == ^GrowthPushRouter.Helpers.normalize_string(provider))
  end

  defp filter_connection_query(query, channel: channel) when is_binary(channel) do
    where(query, [c, _a], c.channel == ^GrowthPushRouter.Helpers.normalize_string(channel))
  end

  defp filter_connection_query(query, status: status) when is_binary(status) do
    where(query, [c, _a], c.status == ^GrowthPushRouter.Helpers.normalize_string(status))
  end

  defp filter_connection_query(query, _), do: query

  defp filter_event_query(query, id: id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> where(query, [e, _c, _a], e.id == ^id)
      :error -> where(query, false)
    end
  end

  defp filter_event_query(query, connection_id: connection_id) when is_binary(connection_id) do
    case Ecto.UUID.cast(connection_id) do
      {:ok, connection_id} -> where(query, [e, _c, _a], e.connection_id == ^connection_id)
      :error -> where(query, false)
    end
  end

  defp filter_event_query(query, provider: provider) when is_binary(provider) do
    where(query, [e, _c, _a], e.provider == ^GrowthPushRouter.Helpers.normalize_string(provider))
  end

  defp filter_event_query(query, channel: channel) when is_binary(channel) do
    where(query, [e, _c, _a], e.channel == ^GrowthPushRouter.Helpers.normalize_string(channel))
  end

  defp filter_event_query(query, status: status) when is_binary(status) do
    where(query, [e, _c, _a], e.status == ^GrowthPushRouter.Helpers.normalize_string(status))
  end

  defp filter_event_query(query, stored_by: stored_by) when is_binary(stored_by) do
    where(
      query,
      [e, _c, _a],
      e.stored_by == ^GrowthPushRouter.Helpers.normalize_string(stored_by)
    )
  end

  defp filter_event_query(query, event_type: event_type) when is_binary(event_type) do
    where(
      query,
      [e, _c, _a],
      e.event_type == ^GrowthPushRouter.Helpers.normalize_string(event_type)
    )
  end

  defp filter_event_query(query, external_event_id: external_event_id)
       when is_binary(external_event_id) do
    where(query, [e, _c, _a], e.external_event_id == ^String.trim(external_event_id))
  end

  defp filter_event_query(query, _), do: query

  defp fetch_event_connection(%Agent{id: agent_id}, connection_id)
       when is_binary(agent_id) and is_binary(connection_id) do
    case Ecto.UUID.cast(connection_id) do
      {:ok, connection_id} ->
        Connection
        |> where([c], c.id == ^connection_id and c.agent_id == ^agent_id)
        |> Repo.one()
        |> case do
          %Connection{} = connection -> {:ok, connection}
          nil -> {:error, :unauthorized}
        end

      :error ->
        {:error, :unauthorized}
    end
  end

  defp fetch_event_connection(_agent, _connection_id), do: {:error, :unauthorized}

  defp fetch_agent_edge_event(%Agent{id: agent_id}, event_id)
       when is_binary(agent_id) and is_binary(event_id) do
    case Ecto.UUID.cast(event_id) do
      {:ok, event_id} ->
        Event
        |> join(:inner, [e], c in assoc(e, :connection))
        |> where([e, c], e.id == ^event_id and c.agent_id == ^agent_id)
        |> where([e, _c], e.stored_by == "edge")
        |> Repo.one()
        |> case do
          %Event{} = event -> {:ok, event}
          nil -> {:error, :unauthorized}
        end

      :error ->
        {:error, :unauthorized}
    end
  end

  defp fetch_agent_edge_event(_agent, _event_id), do: {:error, :unauthorized}

  defp fetch_connection_agent(%User{id: owner_id} = actor_user, agent_id)
       when is_binary(owner_id) and is_binary(agent_id) do
    case list_agents(actor_user, id: agent_id, owner_id: owner_id) do
      {:ok, [%Agent{} = agent]} -> {:ok, agent}
      {:ok, []} -> {:error, :unauthorized}
    end
  end

  defp fetch_connection_agent(_actor_user, _agent_id), do: {:error, :unauthorized}

  defp user_connection_attrs(attrs, %User{id: user_id}, %Agent{id: agent_id}) do
    attrs
    |> Map.take(["external_account_id", "display_name", "access_token_ref", "last_connected_at"])
    |> Map.merge(%{
      "agent_id" => agent_id,
      "connected_by_user_id" => user_id,
      "provider" => "meta",
      "channel" => "instagram",
      "status" => "active"
    })
  end

  defp connection_event_attrs(
         attrs,
         %Connection{
           id: connection_id,
           provider: provider,
           channel: channel
         },
         stored_by
       ) do
    attrs
    |> Map.take([
      "event_type",
      "external_event_id",
      "payload",
      "status",
      "received_at",
      "processed_at"
    ])
    |> Map.merge(%{
      "connection_id" => connection_id,
      "provider" => provider,
      "channel" => channel,
      "stored_by" => stored_by
    })
  end

  defp stringify_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp force_owner_filter(opts, owner_id) do
    opts
    |> Keyword.delete(:owner_id)
    |> Keyword.put(:owner_id, owner_id)
  end
end
