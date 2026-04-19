defmodule BlitzChat.Chat do
  import Ecto.Query
  alias BlitzChat.Repo
  alias BlitzChat.Chat.{Room, Message, RoomMembership}

  # Rooms

  @max_list_limit 100
  @default_list_limit 50

  def list_rooms(opts \\ []) do
    {limit, offset} = paginate(opts)

    from(r in Room,
      where: r.is_archived == false,
      order_by: [asc: r.name],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  def get_room!(id), do: Repo.get!(Room, id)

  def get_room_by_slug!(slug), do: Repo.get_by!(Room, slug: slug)

  def get_room(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get(Room, uuid)
      :error -> nil
    end
  end

  def get_room(_), do: nil

  def get_room_by_slug(slug) when is_binary(slug), do: Repo.get_by(Room, slug: slug)
  def get_room_by_slug(_), do: nil

  def create_room(attrs, created_by \\ nil) do
    do_create_room(attrs, created_by, 0)
  end

  defp do_create_room(attrs, created_by, attempt) do
    changeset =
      %Room{created_by: created_by}
      |> Room.changeset(attrs)
      |> suffix_slug(attempt)

    case Repo.insert(changeset) do
      {:error, %Ecto.Changeset{errors: errors}} = err ->
        if attempt < 3 and Keyword.has_key?(errors, :slug) do
          do_create_room(attrs, created_by, attempt + 1)
        else
          err
        end

      ok ->
        ok
    end
  end

  defp suffix_slug(changeset, 0), do: changeset

  defp suffix_slug(changeset, _attempt) do
    case Ecto.Changeset.get_change(changeset, :slug) do
      nil ->
        changeset

      slug ->
        suffix = :crypto.strong_rand_bytes(3) |> Base.url_encode64(padding: false)
        Ecto.Changeset.put_change(changeset, :slug, "#{slug}-#{suffix}")
    end
  end

  def archive_room(%Room{} = room) do
    room
    |> Ecto.Changeset.change(is_archived: true)
    |> Repo.update()
  end

  # Messages

  def list_messages(room_id, opts \\ []) do
    {limit, _offset} = paginate(opts)
    before = Keyword.get(opts, :before)

    query =
      from m in Message,
        where: m.room_id == ^room_id,
        order_by: [desc: m.inserted_at],
        limit: ^limit,
        preload: [:user]

    query =
      if before do
        from m in query, where: m.inserted_at < ^before
      else
        query
      end

    query
    |> Repo.all()
    |> Enum.reverse()
  end

  def create_message(attrs, room_id, user_id) do
    %Message{room_id: room_id, user_id: user_id}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} -> {:ok, Repo.preload(message, :user)}
      error -> error
    end
  end

  def insert_messages_batch(messages_attrs) when is_list(messages_attrs) do
    now = DateTime.utc_now()

    entries =
      Enum.map(messages_attrs, fn attrs ->
        Map.merge(attrs, %{
          id: Ecto.UUID.generate(),
          inserted_at: now
        })
      end)

    Repo.insert_all(Message, entries)
  end

  # Memberships

  def join_room(room_id, user_id) do
    %RoomMembership{room_id: room_id, user_id: user_id}
    |> RoomMembership.changeset(%{})
    |> Repo.insert(on_conflict: :nothing)
  end

  def leave_room(room_id, user_id) do
    from(m in RoomMembership, where: m.room_id == ^room_id and m.user_id == ^user_id)
    |> Repo.delete_all()
  end

  def list_room_members(room_id, opts \\ []) do
    {limit, offset} = paginate(opts)

    from(m in RoomMembership,
      where: m.room_id == ^room_id,
      join: u in assoc(m, :user),
      select: u,
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  def room_member_count(room_id) do
    from(m in RoomMembership, where: m.room_id == ^room_id, select: count())
    |> Repo.one()
  end

  defp paginate(opts) do
    limit =
      opts
      |> Keyword.get(:limit, @default_list_limit)
      |> min(@max_list_limit)
      |> max(1)

    offset = opts |> Keyword.get(:offset, 0) |> max(0)
    {limit, offset}
  end
end
