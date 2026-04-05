defmodule BlitzChat.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false, size: 100
      add :slug, :string, null: false
      add :description, :text
      add :max_members, :integer, default: 100
      add :is_archived, :boolean, default: false
      add :created_by, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:rooms, [:slug])
    create index(:rooms, [:created_by])
  end
end
