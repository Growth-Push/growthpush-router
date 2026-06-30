defmodule GrowthPushRouter.Agents do
  @moduledoc """
  Domain context for router-agent installations.
  """

  import Ecto.Query, warn: false

  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents.Agent
  alias GrowthPushRouter.Agents.Connection
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

  def fetch_agent(%User{id: owner_id}, id) when is_binary(owner_id) do
    agent = Repo.get!(Agent, id)

    if agent.owner_id == owner_id do
      {:ok, agent}
    else
      {:error, :unauthorized}
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

  defp do_update_agent(%Agent{} = agent, attrs) do
    agent
    |> Agent.admin_changeset(attrs)
    |> Repo.update()
  end

  defp filter_agent_query(query, owner_id: owner_id) when is_binary(owner_id) do
    where(query, [a], a.owner_id == ^owner_id)
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

  defp filter_connection_query(query, connected_by_user_id: connected_by_user_id)
       when is_binary(connected_by_user_id) do
    where(query, [c, _a], c.connected_by_user_id == ^connected_by_user_id)
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

  defp force_owner_filter(opts, owner_id) do
    opts
    |> Keyword.delete(:owner_id)
    |> Keyword.put(:owner_id, owner_id)
  end
end
