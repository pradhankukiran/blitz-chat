defmodule BlitzChat.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "rooms" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :max_members, :integer, default: 100
    field :is_archived, :boolean, default: false

    belongs_to :creator, BlitzChat.Accounts.User, foreign_key: :created_by

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :description, :created_by, :max_members])
    |> validate_required([:name])
    |> validate_length(:name, max: 100)
    |> generate_slug()
    |> unique_constraint(:slug)
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, Slug.slugify(name))
    end
  end
end
