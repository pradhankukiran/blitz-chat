defmodule BlitzChat.Chat.RoomServerTest do
  use BlitzChat.DataCase, async: false

  alias BlitzChat.{Accounts, Chat}
  alias BlitzChat.Chat.{Message, RoomServer, RoomSupervisor}

  setup do
    {:ok, user} =
      Accounts.create_user(%{
        username: "u#{System.unique_integer([:positive])}",
        display_name: "Test"
      })

    {:ok, room} =
      Chat.create_room(%{name: "Room #{System.unique_integer([:positive])}"}, user.id)

    {:ok, pid} = RoomSupervisor.ensure_room_started(room.id)
    Ecto.Adapters.SQL.Sandbox.allow(BlitzChat.Repo, self(), pid)

    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)

    %{user: user, room: room, pid: pid}
  end

  describe "send_message/3" do
    test "persists and broadcasts preloaded Message", %{user: user, room: room} do
      Phoenix.PubSub.subscribe(BlitzChat.PubSub, "room:#{room.id}")

      assert {:ok, %Message{body: "hello"} = msg} =
               RoomServer.send_message(room.id, user.id, "hello")

      assert msg.user.id == user.id
      assert_receive {:new_message, %Message{body: "hello", user: %Accounts.User{}}}, 1_000

      assert [_] = Chat.list_messages(room.id)
    end

    test "rejects empty body", %{user: user, room: room} do
      assert {:error, :empty_body} = RoomServer.send_message(room.id, user.id, "")
      assert {:error, :empty_body} = RoomServer.send_message(room.id, user.id, "   ")
    end

    test "rejects body > 5000 bytes", %{user: user, room: room} do
      big = String.duplicate("x", 5001)
      assert {:error, :body_too_long} = RoomServer.send_message(room.id, user.id, big)
    end

    test "concurrent sends all persist exactly once", %{user: user, room: room} do
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            RoomServer.send_message(room.id, user.id, "msg #{i}")
          end)
        end

      results = Task.await_many(tasks, 5_000)
      assert Enum.all?(results, &match?({:ok, _}, &1))

      assert length(Chat.list_messages(room.id, limit: 100)) == 20
    end
  end

  describe "get_stats/1" do
    test "returns room_id, slug, memory", %{room: room} do
      stats = RoomServer.get_stats(room.id)
      assert stats.room_id == room.id
      assert is_binary(stats.room_slug)
      assert is_integer(stats.memory)
    end
  end
end
