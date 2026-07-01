defmodule GrowthPushRouter.Repo.Migrations.AddAgentOutboxFieldsToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :stored_by, :string, null: false, default: "edge"
      add :sequence, :bigserial, null: false
    end

    create unique_index(:events, [:sequence])
    create index(:events, [:stored_by, :sequence])
    create index(:events, [:connection_id, :stored_by])
  end
end
