defmodule GrowthPushRouter.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :connection_id, references(:connections, type: :uuid, on_delete: :delete_all),
        null: false

      add :provider, :string, null: false
      add :channel, :string, null: false
      add :event_type, :string, null: false
      add :external_event_id, :string
      add :payload, :map, null: false, default: %{}
      add :status, :string, null: false, default: "received"
      add :received_at, :utc_datetime, null: false, default: fragment("now()")
      add :processed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:events, [:connection_id])
    create index(:events, [:status])
    create index(:events, [:received_at])
    create index(:events, [:provider, :channel])
  end
end
