defmodule BlitzChat.Repo.Migrations.FixMessageUserFk do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      modify :user_id,
             references(:users, type: :binary_id, on_delete: :delete_all),
             null: false,
             from: references(:users, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
