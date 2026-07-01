defmodule GrowthPushRouter.Agents.Connection do
  @moduledoc """
  Connected external channel persisted for a router agent.
  """

  use Ecto.Schema
  use Gettext, backend: GrowthPushRouterWeb.Gettext

  import Ecto.Changeset

  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents.Agent
  alias GrowthPushRouter.Agents.Event
  alias GrowthPushRouter.Helpers

  @providers ~w(meta)
  @channels ~w(instagram)
  @statuses ~w(active inactive error)
  @required ~w(agent_id connected_by_user_id provider channel external_account_id display_name access_token_ref status)a
  @optional ~w(scopes last_connected_at last_checked_at last_error_at last_errors)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "connections" do
    field :provider, :string
    field :channel, :string
    field :external_account_id, :string
    field :display_name, :string
    field :access_token_ref, :string, redact: true
    field :scopes, {:array, :string}, default: []
    field :status, :string, default: "active"
    field :last_connected_at, :utc_datetime
    field :last_checked_at, :utc_datetime
    field :last_error_at, :utc_datetime
    field :last_errors, :map, default: %{}

    belongs_to :agent, Agent
    belongs_to :connected_by_user, User
    has_many :events, Event

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for admin-managed connection fields.

  ## Examples

      iex> alias GrowthPushRouter.Agents.Connection
      iex> changeset =
      ...>   Connection.admin_changeset(%Connection{}, %{
      ...>     "agent_id" => Ecto.UUID.generate(),
      ...>     "connected_by_user_id" => Ecto.UUID.generate(),
      ...>     "provider" => " Meta ",
      ...>     "channel" => " Instagram ",
      ...>     "external_account_id" => "17841400000000000",
      ...>     "display_name" => "Growth Push",
      ...>     "access_token_ref" => "vault://meta/instagram/growth-push"
      ...>   })
      iex> changeset.valid?
      true
      iex> Ecto.Changeset.get_change(changeset, :provider)
      "meta"

  """
  def admin_changeset(connection, attrs) do
    connection
    |> cast(attrs, @required ++ @optional)
    |> update_change(:provider, &Helpers.normalize_string/1)
    |> update_change(:channel, &Helpers.normalize_string/1)
    |> update_change(:status, &Helpers.normalize_string/1)
    |> update_change(:external_account_id, &normalize_optional_string/1)
    |> update_change(:display_name, &normalize_optional_string/1)
    |> update_change(:access_token_ref, &normalize_optional_string/1)
    |> validate_required(@required, message: dgettext("errors", ".cant_be_blank"))
    |> validate_length(:provider, max: 80, message: dgettext("errors", ".too_long", count: 80))
    |> validate_length(:channel, max: 80, message: dgettext("errors", ".too_long", count: 80))
    |> validate_length(:external_account_id,
      max: 255,
      message: dgettext("errors", ".too_long", count: 255)
    )
    |> validate_length(:display_name,
      max: 255,
      message: dgettext("errors", ".too_long", count: 255)
    )
    |> validate_length(:access_token_ref,
      max: 500,
      message: dgettext("errors", ".too_long", count: 500)
    )
    |> validate_access_token_ref()
    |> validate_inclusion(:provider, @providers,
      message: dgettext("errors", ".connection_provider_invalid")
    )
    |> validate_inclusion(:channel, @channels,
      message: dgettext("errors", ".connection_channel_invalid")
    )
    |> validate_inclusion(:status, @statuses,
      message: dgettext("errors", ".connection_status_invalid")
    )
    |> unique_constraint(:external_account_id,
      name: :connections_provider_channel_external_account_id_index,
      message: dgettext("errors", ".connection_external_account_unique_error")
    )
    |> foreign_key_constraint(:agent_id,
      message: dgettext("errors", ".connection_agent_not_found")
    )
    |> foreign_key_constraint(:connected_by_user_id,
      message: dgettext("errors", ".connection_connected_by_user_not_found")
    )
  end

  @doc """
  Returns the allowed connection statuses.

  ## Examples

      iex> GrowthPushRouter.Agents.Connection.statuses()
      ["active", "inactive", "error"]

  """
  def statuses, do: @statuses

  defp validate_access_token_ref(changeset) do
    validate_change(changeset, :access_token_ref, fn :access_token_ref, access_token_ref ->
      access_token_ref
      |> token_ref?()
      |> access_token_ref_error()
    end)
  end

  defp token_ref?(access_token_ref) when is_binary(access_token_ref) do
    uri = URI.parse(access_token_ref)

    is_binary(uri.scheme) and uri.scheme != "" and is_binary(uri.host) and uri.host != ""
  end

  defp token_ref?(_), do: false

  defp access_token_ref_error(true), do: []

  defp access_token_ref_error(false) do
    [access_token_ref: {dgettext("errors", ".connection_access_token_ref_invalid"), []}]
  end

  defp normalize_optional_string(value) when is_binary(value), do: String.trim(value)
  defp normalize_optional_string(value), do: value
end
