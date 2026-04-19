defmodule BlitzChat.ApiKeys do
  alias BlitzChat.Repo
  alias BlitzChat.ApiKeys.ApiKey

  def create_key(attrs, user_id \\ nil) do
    raw_key = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    key_hash = hash_key(raw_key)
    key_prefix = String.slice(raw_key, 0, 8)

    result =
      %ApiKey{user_id: user_id}
      |> ApiKey.changeset(Map.merge(attrs, %{key_hash: key_hash, key_prefix: key_prefix}))
      |> Repo.insert()

    case result do
      {:ok, api_key} -> {:ok, api_key, raw_key}
      error -> error
    end
  end

  def verify_key(raw_key) do
    key_hash = hash_key(raw_key)
    prefix = String.slice(raw_key, 0, 8)

    case Repo.get_by(ApiKey, key_prefix: prefix, key_hash: key_hash, is_active: true) do
      nil -> :error
      api_key -> if expired?(api_key), do: :error, else: {:ok, api_key}
    end
  end

  defp expired?(%ApiKey{expires_at: nil}), do: false

  defp expired?(%ApiKey{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  def revoke_key(id) do
    ApiKey
    |> Repo.get!(id)
    |> Ecto.Changeset.change(is_active: false)
    |> Repo.update()
  end

  def list_keys(opts \\ []) do
    import Ecto.Query

    limit = opts |> Keyword.get(:limit, 50) |> min(100) |> max(1)
    offset = opts |> Keyword.get(:offset, 0) |> max(0)

    query =
      case Keyword.get(opts, :user_id) do
        nil -> from(k in ApiKey)
        user_id -> from(k in ApiKey, where: k.user_id == ^user_id)
      end

    query
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  defp hash_key(raw_key) do
    :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)
  end
end
