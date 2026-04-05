defmodule BlitzChat.Chat do
  import Ecto.Query
  alias BlitzChat.Repo
  alias BlitzChat.Chat.{Room, Message, RoomMembership}

  # Rooms

  def list_rooms do
    Repo.all(from r in Room, where: r.is_archived == false, order_by: [asc: r.name])
  end

  def get_room!(id), do: Repo.get!(Room, id)

  def get_room_by_slug!(slug), do: Repo.get_by!(Room, slug: slug)

  def create_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  def archive_room(%Room{} = room) do
    room
    |> Ecto.Changeset.change(is_archived: true)
    |> Repo.update()
  end

  # Messages

  def list_messages(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
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

  def create_message(attrs) do
    %Message{}
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
    %RoomMembership{}
    |> RoomMembership.changeset(%{room_id: room_id, user_id: user_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  def leave_room(room_id, user_id) do
    from(m in RoomMembership, where: m.room_id == ^room_id and m.user_id == ^user_id)
    |> Repo.delete_all()
  end

  def list_room_members(room_id) do
    from(m in RoomMembership,
      where: m.room_id == ^room_id,
      join: u in assoc(m, :user),
      select: u
    )
    |> Repo.all()
  end

  def room_member_count(room_id) do
    from(m in RoomMembership, where: m.room_id == ^room_id, select: count())
    |> Repo.one()
  end
end
