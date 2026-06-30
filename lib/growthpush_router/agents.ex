defmodule GrowthPushRouter.Agents do
  @moduledoc """
  Domain context for router-agent installations.
  """

  import Ecto.Query, warn: false

  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents.Agent
  alias GrowthPushRouter.Repo

  @doc """
  Lists agents visible to an admin actor.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = %User{email: "admin@example.test"}
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
  def list_agents(admin_user, opts \\ [])

  def list_agents(%User{} = admin_user, opts) do
    with :ok <- authorize_admin(admin_user) do
      {:ok, do_list_agents(opts)}
    end
  end

  def list_agents(_admin_user, _opts), do: {:error, :unauthorized}

  @doc """
  Fetches an agent for an admin or owner actor.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = %User{email: "admin@example.test"}
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
  def fetch_agent(%User{} = actor_user, id) do
    agent = Repo.get!(Agent, id)

    if allowed_to_fetch?(actor_user, agent) do
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
      iex> admin = %User{email: "admin@example.test"}
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
  def create_agent(%User{} = admin_user, attrs) do
    with :ok <- authorize_admin(admin_user) do
      do_create_agent(attrs)
    end
  end

  def create_agent(_admin_user, _attrs), do: {:error, :unauthorized}

  @doc """
  Updates an agent as an admin operation.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = %User{email: "admin@example.test"}
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
  def update_agent(%User{} = admin_user, %Agent{} = agent, attrs) do
    with :ok <- authorize_admin(admin_user) do
      do_update_agent(agent, attrs)
    end
  end

  def update_agent(_admin_user, _agent, _attrs), do: {:error, :unauthorized}

  @doc """
  Deletes an agent as an admin operation.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> alias GrowthPushRouter.Agents
      iex> admin = %User{email: "admin@example.test"}
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
  def delete_agent(%User{} = admin_user, %Agent{} = agent) do
    with :ok <- authorize_admin(admin_user), do: Repo.delete(agent)
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

  defp do_list_agents(opts) do
    query = from(a in Agent)

    opts
    |> Enum.reduce(query, fn filter, q ->
      filter_query(q, [filter])
    end)
    |> order_by([a], asc: a.inserted_at)
    |> Repo.all()
  end

  defp do_create_agent(attrs) do
    %Agent{}
    |> Agent.admin_changeset(attrs)
    |> Repo.insert()
  end

  defp do_update_agent(%Agent{} = agent, attrs) do
    agent
    |> Agent.admin_changeset(attrs)
    |> Repo.update()
  end

  defp allowed_to_fetch?(%User{} = actor_user, %Agent{} = agent) do
    User.admin?(actor_user) or actor_user.id == agent.owner_id
  end

  defp authorize_admin(%User{} = user) do
    if User.admin?(user), do: :ok, else: {:error, :unauthorized}
  end

  defp filter_query(query, owner_id: owner_id) when is_binary(owner_id) do
    where(query, [a], a.owner_id == ^owner_id)
  end

  defp filter_query(query, slug: slug) when is_binary(slug) do
    where(query, [a], a.slug == ^GrowthPushRouter.Helpers.normalize_string(slug))
  end

  defp filter_query(query, status: status) when is_binary(status) do
    where(query, [a], a.status == ^status)
  end

  defp filter_query(query, _), do: query
end
