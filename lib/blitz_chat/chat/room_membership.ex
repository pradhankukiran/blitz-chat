defmodule BlitzChat.Chat.RoomMembership do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "room_memberships" do
    field :role, :string, default: "member"

    belongs_to :room, BlitzChat.Chat.Room
    belongs_to :user, BlitzChat.Accounts.User

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role])
    |> validate_inclusion(:role, ["member", "admin"])
    |> unique_constraint([:room_id, :user_id])
    |> foreign_key_constraint(:room_id)
    |> foreign_key_constraint(:user_id)
  end
end
