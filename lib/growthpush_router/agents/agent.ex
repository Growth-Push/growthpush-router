defmodule GrowthPushRouter.Agents.Agent do
  @moduledoc """
  Agent-side router installation persisted by Growth Push Router.
  """

  use Ecto.Schema
  use Gettext, backend: GrowthPushRouterWeb.Gettext

  import Ecto.Changeset

  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents.Connection
  alias GrowthPushRouter.Helpers
  alias GrowthPushRouter.Repo

  @statuses ~w(inactive active error)
  @required ~w(owner_id slug endpoint_url)a
  @optional ~w(status last_seen_at last_errors shared_secret)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agents" do
    field :slug, :string
    field :endpoint_url, :string
    field :status, :string, default: "inactive"
    field :shared_secret, :string, virtual: true, redact: true
    field :shared_secret_hash, :string, redact: true
    field :last_seen_at, :utc_datetime
    field :last_errors, :map, default: %{}

    belongs_to :owner, User
    has_many :connections, Connection

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for admin-managed agent fields.

  ## Examples

      iex> alias GrowthPushRouter.Agents.Agent
      iex> changeset =
      ...>   Agent.admin_changeset(%Agent{}, %{
      ...>     "owner_id" => Ecto.UUID.generate(),
      ...>     "slug" => " Client-Agent ",
      ...>     "endpoint_url" => "https://agent.example.test/events",
      ...>     "shared_secret" => "agent-secret-1234"
      ...>   })
      iex> changeset.valid?
      true
      iex> Ecto.Changeset.get_change(changeset, :slug)
      "client-agent"

  """
  def admin_changeset(agent, attrs) do
    agent
    |> cast(attrs, @required ++ @optional)
    |> update_change(:slug, &Helpers.normalize_string/1)
    |> validate_required(@required, message: dgettext("errors", ".cant_be_blank"))
    |> validate_required_secret()
    |> validate_length(:slug, max: 80, message: dgettext("errors", ".too_long", count: 80))
    |> validate_format(:slug, ~r/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/,
      message: dgettext("errors", ".agent_slug_format")
    )
    |> validate_length(:endpoint_url,
      max: 500,
      message: dgettext("errors", ".too_long", count: 500)
    )
    |> validate_endpoint_url()
    |> validate_inclusion(:status, @statuses,
      message: dgettext("errors", ".agent_status_invalid")
    )
    |> validate_length(:shared_secret,
      min: 16,
      message: dgettext("errors", ".agent_secret_too_short")
    )
    |> validate_length(:shared_secret,
      max: 72,
      count: :bytes,
      message: dgettext("errors", ".agent_secret_too_long")
    )
    |> maybe_hash_secret()
    |> unsafe_validate_unique(:slug, Repo,
      message: dgettext("errors", ".agent_slug_unique_error")
    )
    |> unique_constraint(:slug,
      name: :agents_slug_index,
      message: dgettext("errors", ".agent_slug_unique_error")
    )
    |> foreign_key_constraint(:owner_id, message: dgettext("errors", ".agent_owner_not_found"))
  end

  @doc """
  Returns the allowed agent statuses.

  ## Examples

      iex> GrowthPushRouter.Agents.Agent.statuses()
      ["inactive", "active", "error"]

  """
  def statuses, do: @statuses

  defp validate_required_secret(changeset) do
    if get_field(changeset, :shared_secret_hash) in [nil, ""] do
      validate_required(changeset, [:shared_secret],
        message: dgettext("errors", ".cant_be_blank")
      )
    else
      changeset
    end
  end

  defp validate_endpoint_url(changeset) do
    validate_change(changeset, :endpoint_url, fn :endpoint_url, endpoint_url ->
      endpoint_url
      |> valid_endpoint_url?()
      |> endpoint_url_error()
    end)
  end

  defp valid_endpoint_url?(endpoint_url) when is_binary(endpoint_url) do
    uri = URI.parse(endpoint_url)

    uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != ""
  end

  defp valid_endpoint_url?(_), do: false

  defp endpoint_url_error(true), do: []

  defp endpoint_url_error(false) do
    [endpoint_url: {dgettext("errors", ".agent_endpoint_url_invalid"), []}]
  end

  defp maybe_hash_secret(changeset) do
    secret = get_change(changeset, :shared_secret)

    if secret && changeset.valid? do
      changeset
      |> put_change(:shared_secret_hash, Bcrypt.hash_pwd_salt(secret))
      |> delete_change(:shared_secret)
    else
      changeset
    end
  end
end
