defmodule GrowthPushRouter.Agents.Event do
  @moduledoc """
  Raw inbound event received through a connected external channel.
  """

  use Ecto.Schema
  use Gettext, backend: GrowthPushRouterWeb.Gettext

  import Ecto.Changeset

  alias GrowthPushRouter.Agents.Connection
  alias GrowthPushRouter.Helpers

  @statuses ~w(received processing processed failed ignored)
  @required ~w(connection_id provider channel event_type payload status received_at)a
  @optional ~w(external_event_id processed_at)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "events" do
    field :provider, :string
    field :channel, :string
    field :event_type, :string
    field :external_event_id, :string
    field :payload, :map, default: %{}
    field :status, :string, default: "received"
    field :received_at, :utc_datetime
    field :processed_at, :utc_datetime

    belongs_to :connection, Connection

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for a raw inbound connection event.

  ## Examples

      iex> alias GrowthPushRouter.Agents.Event
      iex> received_at = ~U[2026-07-01 12:00:00Z]
      iex> changeset =
      ...>   Event.changeset(%Event{}, %{
      ...>     "connection_id" => Ecto.UUID.generate(),
      ...>     "provider" => " Meta ",
      ...>     "channel" => " Instagram ",
      ...>     "event_type" => " Message_Received ",
      ...>     "payload" => %{"entry" => [%{"id" => "17841400000000000"}]},
      ...>     "received_at" => received_at
      ...>   })
      iex> changeset.valid?
      true
      iex> Ecto.Changeset.get_change(changeset, :provider)
      "meta"

  """
  def changeset(event, attrs) do
    event
    |> cast(attrs, @required ++ @optional)
    |> update_change(:provider, &Helpers.normalize_string/1)
    |> update_change(:channel, &Helpers.normalize_string/1)
    |> update_change(:status, &Helpers.normalize_string/1)
    |> update_change(:event_type, &Helpers.normalize_string/1)
    |> update_change(:external_event_id, &normalize_optional_string/1)
    |> put_default_received_at()
    |> validate_required(@required, message: dgettext("errors", ".cant_be_blank"))
    |> validate_length(:provider, max: 80, message: dgettext("errors", ".too_long", count: 80))
    |> validate_length(:channel, max: 80, message: dgettext("errors", ".too_long", count: 80))
    |> validate_length(:event_type,
      max: 255,
      message: dgettext("errors", ".too_long", count: 255)
    )
    |> validate_length(:external_event_id,
      max: 255,
      message: dgettext("errors", ".too_long", count: 255)
    )
    |> validate_inclusion(:status, @statuses,
      message: dgettext("errors", ".event_status_invalid")
    )
    |> foreign_key_constraint(:connection_id,
      message: dgettext("errors", ".event_connection_not_found")
    )
  end

  @doc """
  Returns the allowed event statuses.

  ## Examples

      iex> GrowthPushRouter.Agents.Event.statuses()
      ["received", "processing", "processed", "failed", "ignored"]

  """
  def statuses, do: @statuses

  defp put_default_received_at(changeset) do
    if get_field(changeset, :received_at) do
      changeset
    else
      put_change(changeset, :received_at, DateTime.utc_now(:second))
    end
  end

  defp normalize_optional_string(value) when is_binary(value), do: String.trim(value)
  defp normalize_optional_string(value), do: value
end
