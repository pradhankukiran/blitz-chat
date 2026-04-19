defmodule BlitzChat.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :username, :string
    field :display_name, :string
    field :avatar_url, :string
    field :admin, :boolean, default: false

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :display_name, :avatar_url])
    |> validate_required([:username, :display_name])
    |> validate_length(:username, max: 30)
    |> validate_length(:display_name, max: 100)
    |> validate_format(:username, ~r/^[a-z0-9_]+$/, message: "only lowercase letters, numbers, and underscores")
    |> update_change(:username, &String.downcase/1)
    |> unique_constraint(:username)
  end

  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:admin])
    |> validate_required([:admin])
  end
end
