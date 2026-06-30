defmodule GrowthPushRouter.Repo.Migrations.CreateConnections do
  use Ecto.Migration

  def change do
    create table(:connections, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :agent_id, references(:agents, type: :uuid, on_delete: :delete_all), null: false

      add :connected_by_user_id, references(:users, type: :uuid, on_delete: :nothing), null: false

      add :provider, :string, null: false
      add :channel, :string, null: false
      add :external_account_id, :string, null: false
      add :display_name, :string, null: false
      add :access_token_ref, :string, null: false
      add :scopes, {:array, :string}, null: false, default: []
      add :status, :string, null: false, default: "active"
      add :last_connected_at, :utc_datetime
      add :last_checked_at, :utc_datetime
      add :last_error_at, :utc_datetime
      add :last_errors, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:connections, [:agent_id])
    create index(:connections, [:connected_by_user_id])

    create unique_index(:connections, [:provider, :channel, :external_account_id],
             name: :connections_provider_channel_external_account_id_index
           )
  end
end
