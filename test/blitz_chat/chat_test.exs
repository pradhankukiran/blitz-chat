defmodule BlitzChat.ChatTest do
  use BlitzChat.DataCase, async: true

  alias BlitzChat.Accounts
  alias BlitzChat.Chat
  alias BlitzChat.Chat.{Message, Room}

  defp user_fixture(attrs \\ %{}) do
    defaults = %{
      username: "u#{System.unique_integer([:positive])}",
      display_name: "Test User"
    }

    {:ok, user} = Accounts.create_user(Map.merge(defaults, attrs))
    user
  end

  defp room_fixture(%Accounts.User{id: creator_id}, attrs \\ %{}) do
    defaults = %{name: "Room #{System.unique_integer([:positive])}"}
    {:ok, room} = Chat.create_room(Map.merge(defaults, attrs), creator_id)
    room
  end

  describe "create_room/2" do
    test "sets created_by from explicit arg, not from attrs (no mass-assignment)" do
      creator = user_fixture()
      attacker = user_fixture()

      {:ok, room} =
        Chat.create_room(%{name: "General", created_by: attacker.id}, creator.id)

      assert room.created_by == creator.id
    end

    test "retries with random slug suffix on collision" do
      creator = user_fixture()
      {:ok, a} = Chat.create_room(%{name: "General"}, creator.id)
      {:ok, b} = Chat.create_room(%{name: "General"}, creator.id)

      assert a.slug == "general"
      assert b.slug =~ ~r/^general-/
      refute a.slug == b.slug
    end

    test "validates name required and max 100 chars" do
      creator = user_fixture()
      assert {:error, cs} = Chat.create_room(%{name: ""}, creator.id)
      assert %{name: _} = errors_on(cs)

      long_name = String.duplicate("a", 101)
      assert {:error, cs} = Chat.create_room(%{name: long_name}, creator.id)
      assert %{name: _} = errors_on(cs)
    end
  end

  describe "list_rooms/1" do
    test "returns only non-archived rooms" do
      creator = user_fixture()
      {:ok, active} = Chat.create_room(%{name: "Active"}, creator.id)
      {:ok, archived} = Chat.create_room(%{name: "Old"}, creator.id)
      {:ok, _} = Chat.archive_room(archived)

      ids = Chat.list_rooms() |> Enum.map(& &1.id)
      assert active.id in ids
      refute archived.id in ids
    end

    test "caps limit to 100" do
      creator = user_fixture()
      for i <- 1..5, do: room_fixture(creator, %{name: "Room #{i}"})

      assert length(Chat.list_rooms(limit: 1_000_000)) <= 100
    end
  end

  describe "create_message/3" do
    test "sets room_id and user_id explicitly (no mass-assignment)" do
      creator = user_fixture()
      attacker = user_fixture()
      room = room_fixture(creator)

      {:ok, msg} =
        Chat.create_message(
          %{body: "hello", room_id: "00000000-0000-0000-0000-000000000001", user_id: attacker.id},
          room.id,
          creator.id
        )

      assert msg.room_id == room.id
      assert msg.user_id == creator.id
    end

    test "validates body length 1..5000" do
      creator = user_fixture()
      room = room_fixture(creator)

      assert {:error, cs} = Chat.create_message(%{body: ""}, room.id, creator.id)
      assert %{body: _} = errors_on(cs)

      assert {:error, cs} =
               Chat.create_message(%{body: String.duplicate("x", 5001)}, room.id, creator.id)

      assert %{body: _} = errors_on(cs)
    end

    test "preloads user on success" do
      creator = user_fixture()
      room = room_fixture(creator)

      {:ok, %Message{user: %Accounts.User{}} = msg} =
        Chat.create_message(%{body: "hi"}, room.id, creator.id)

      assert msg.user.id == creator.id
    end
  end

  describe "list_messages/2" do
    test "caps limit to 100 and orders ASC by inserted_at" do
      creator = user_fixture()
      room = room_fixture(creator)

      for i <- 1..5 do
        {:ok, _} = Chat.create_message(%{body: "m#{i}"}, room.id, creator.id)
      end

      messages = Chat.list_messages(room.id, limit: 1_000_000)
      assert length(messages) <= 100
      assert messages == Enum.sort_by(messages, & &1.inserted_at)
    end

    test "respects :before cutoff" do
      creator = user_fixture()
      room = room_fixture(creator)

      {:ok, m1} = Chat.create_message(%{body: "1"}, room.id, creator.id)
      Process.sleep(1)
      {:ok, _m2} = Chat.create_message(%{body: "2"}, room.id, creator.id)

      older = Chat.list_messages(room.id, before: m1.inserted_at)
      assert older == []
    end
  end

  describe "join_room/2" do
    test "creates a membership, second call is idempotent (on_conflict :nothing)" do
      creator = user_fixture()
      member = user_fixture()
      room = room_fixture(creator)

      assert {:ok, _m1} = Chat.join_room(room.id, member.id)
      assert {:ok, _m2} = Chat.join_room(room.id, member.id)
      assert Chat.room_member_count(room.id) == 1
    end
  end

  describe "get_room/1 and get_room_by_slug/1 (non-raising)" do
    test "returns nil on missing id" do
      assert Chat.get_room("00000000-0000-0000-0000-000000000000") == nil
    end

    test "returns nil on invalid uuid" do
      assert Chat.get_room("not-a-uuid") == nil
    end

    test "returns nil on missing slug" do
      assert Chat.get_room_by_slug("does-not-exist") == nil
    end

    test "returns the room when found" do
      creator = user_fixture()
      room = room_fixture(creator, %{name: "FindMe"})
      expected_id = room.id
      assert %Room{id: ^expected_id} = Chat.get_room(room.id)
      assert %Room{id: ^expected_id} = Chat.get_room_by_slug("findme")
    end
  end
end
