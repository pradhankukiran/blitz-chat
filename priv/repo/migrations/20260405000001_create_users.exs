defmodule BlitzChat.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :string, null: false, size: 30
      add :display_name, :string, null: false, size: 100
      add :avatar_url, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:username])
  end
end
