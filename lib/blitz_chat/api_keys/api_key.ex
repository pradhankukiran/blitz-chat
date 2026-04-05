defmodule BlitzChat.ApiKeys.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "api_keys" do
    field :label, :string
    field :key_hash, :string
    field :key_prefix, :string
    field :is_active, :boolean, default: true

    belongs_to :user, BlitzChat.Accounts.User

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:label, :key_hash, :key_prefix, :is_active, :user_id])
    |> validate_required([:label, :key_hash, :key_prefix])
  end
end
