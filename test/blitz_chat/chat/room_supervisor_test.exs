defmodule BlitzChat.Chat.RoomSupervisorTest do
  use BlitzChat.DataCase, async: false

  alias BlitzChat.{Accounts, Chat}
  alias BlitzChat.Chat.RoomSupervisor

  setup do
    {:ok, user} =
      Accounts.create_user(%{
        username: "u#{System.unique_integer([:positive])}",
        display_name: "t"
      })

    {:ok, room} =
      Chat.create_room(%{name: "Room #{System.unique_integer([:positive])}"}, user.id)

    %{room: room}
  end

  describe "ensure_room_started/1" do
    test "concurrent callers all get {:ok, pid} and hit the same process", %{room: room} do
      parent = self()

      tasks =
        for _ <- 1..50 do
          Task.async(fn ->
            result = RoomSupervisor.ensure_room_started(room.id)
            send(parent, {:result, result})
            result
          end)
        end

      results = Task.await_many(tasks, 5_000)
      pids = for {:ok, pid} <- results, do: pid

      assert length(pids) == 50
      assert pids |> Enum.uniq() |> length() == 1

      [pid] = Enum.uniq(pids)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
    end

    test "returns existing pid when room is already running", %{room: room} do
      {:ok, pid1} = RoomSupervisor.ensure_room_started(room.id)
      {:ok, pid2} = RoomSupervisor.ensure_room_started(room.id)
      assert pid1 == pid2
      on_exit(fn -> if Process.alive?(pid1), do: GenServer.stop(pid1, :normal) end)
    end
  end
end
