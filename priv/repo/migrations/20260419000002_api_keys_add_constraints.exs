defmodule BlitzChat.Repo.Migrations.ApiKeysAddConstraints do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :expires_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec
      add :scopes, {:array, :string}, default: ["read"], null: false
    end

    create unique_index(:api_keys, [:key_hash])
  end
end
