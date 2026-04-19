defmodule BlitzChat.Repo.Migrations.AddQueryIndexes do
  use Ecto.Migration

  def change do
    create index(:rooms, [:is_archived])
    create index(:room_memberships, [:user_id])
    create index(:messages, [:user_id])
  end
end
