defmodule BlitzChat.Repo.Migrations.CreateRoomMemberships do
  use Ecto.Migration

  def change do
    create table(:room_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, default: "member"
      add :room_id, references(:rooms, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:room_memberships, [:room_id, :user_id])
  end
end
