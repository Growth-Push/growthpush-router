defmodule GrowthPushRouter.Repo.Migrations.CreateAgents do
  use Ecto.Migration

  def change do
    create table(:agents, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :owner_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :endpoint_url, :string, null: false
      add :status, :string, null: false, default: "inactive"
      add :shared_secret_hash, :string, null: false
      add :last_seen_at, :utc_datetime
      add :last_errors, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:agents, [:slug], name: :agents_slug_index)
    create index(:agents, [:owner_id])
  end
end
