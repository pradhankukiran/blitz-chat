defmodule BlitzChat.Chat.RoomSupervisor do
  alias BlitzChat.Chat.RoomServer

  def start_room(room_id) do
    DynamicSupervisor.start_child(__MODULE__, {RoomServer, room_id})
  end

  def ensure_room_started(room_id) do
    case Registry.lookup(BlitzChat.RoomRegistry, room_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> start_room(room_id)
    end
  end

  def active_room_count do
    DynamicSupervisor.count_children(__MODULE__).active
  end

  def active_rooms do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} ->
      try do
        GenServer.call(pid, :get_stats, 1000)
      catch
        :exit, _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
