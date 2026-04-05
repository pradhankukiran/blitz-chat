defmodule BlitzChat.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :label, :string, null: false
      add :key_hash, :string, null: false
      add :key_prefix, :string, null: false
      add :is_active, :boolean, default: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:api_keys, [:key_prefix])
  end
end
