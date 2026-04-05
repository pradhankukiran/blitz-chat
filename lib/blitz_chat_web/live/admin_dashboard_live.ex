defmodule BlitzChatWeb.AdminDashboardLive do
  use BlitzChatWeb, :live_view

  alias BlitzChat.Chat.RoomSupervisor

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(1000, :refresh)
    end

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign_stats()}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, assign_stats(socket)}
  end

  defp assign_stats(socket) do
    room_stats = RoomSupervisor.active_rooms()

    socket
    |> assign(:active_rooms, RoomSupervisor.active_room_count())
    |> assign(:room_stats, room_stats)
    |> assign(:total_messages, Enum.reduce(room_stats, 0, fn s, acc -> acc + s.total_messages end))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold text-gray-900">Admin Dashboard</h1>
          <.link navigate={~p"/"} class="btn btn-ghost btn-sm rounded-none">&larr; Lobby</.link>
        </div>

        <%!-- Stats cards --%>
        <div class="grid grid-cols-3 gap-4">
          <div class="border border-gray-200 p-6">
            <p class="text-xs font-semibold text-gray-400 uppercase tracking-wide">Active Rooms</p>
            <p class="text-3xl font-bold text-gray-900 mt-1">{@active_rooms}</p>
          </div>
          <div class="border border-gray-200 p-6">
            <p class="text-xs font-semibold text-gray-400 uppercase tracking-wide">Total Messages</p>
            <p class="text-3xl font-bold text-gray-900 mt-1">{@total_messages}</p>
          </div>
          <div class="border border-gray-200 p-6">
            <p class="text-xs font-semibold text-gray-400 uppercase tracking-wide">BEAM Processes</p>
            <p class="text-3xl font-bold text-gray-900 mt-1">{:erlang.system_info(:process_count)}</p>
          </div>
        </div>

        <%!-- Room processes table --%>
        <div class="border border-gray-200">
          <div class="px-4 py-3 border-b border-gray-200">
            <h2 class="text-sm font-semibold text-gray-900">Active Room Processes</h2>
          </div>
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-gray-100 text-left text-xs text-gray-400 uppercase tracking-wide">
                <th class="px-4 py-2 font-medium">Room</th>
                <th class="px-4 py-2 font-medium">Messages</th>
                <th class="px-4 py-2 font-medium">Buffer</th>
                <th class="px-4 py-2 font-medium">Memory</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={room <- @room_stats} class="border-b border-gray-50">
                <td class="px-4 py-2 font-medium text-gray-900">{room.room_slug}</td>
                <td class="px-4 py-2 text-gray-600">{room.total_messages}</td>
                <td class="px-4 py-2 text-gray-600">{room.buffer_size}</td>
                <td class="px-4 py-2 text-gray-600">{format_bytes(room.memory)}</td>
              </tr>
              <tr :if={@room_stats == []}>
                <td colspan="4" class="px-4 py-8 text-center text-gray-400">No active room processes</td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- BEAM info --%>
        <div class="border border-gray-200 p-4">
          <h2 class="text-sm font-semibold text-gray-900 mb-3">BEAM Runtime</h2>
          <div class="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span class="text-gray-400">Schedulers:</span>
              <span class="text-gray-900 ml-2">{:erlang.system_info(:schedulers_online)}</span>
            </div>
            <div>
              <span class="text-gray-400">Atoms:</span>
              <span class="text-gray-900 ml-2">{:erlang.system_info(:atom_count)}</span>
            </div>
            <div>
              <span class="text-gray-400">Total Memory:</span>
              <span class="text-gray-900 ml-2">{format_bytes(:erlang.memory(:total))}</span>
            </div>
            <div>
              <span class="text-gray-400">Process Memory:</span>
              <span class="text-gray-900 ml-2">{format_bytes(:erlang.memory(:processes))}</span>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
