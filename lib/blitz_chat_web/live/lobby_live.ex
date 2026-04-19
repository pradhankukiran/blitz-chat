defmodule BlitzChatWeb.LobbyLive do
  use BlitzChatWeb, :live_view

  alias BlitzChat.Chat

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BlitzChat.PubSub, "lobby")
    end

    rooms = Chat.list_rooms()

    {:ok,
     socket
     |> assign(:page_title, "Lobby")
     |> stream(:rooms, rooms)}
  end

  @impl true
  def handle_event("create_room", %{"name" => name, "description" => description}, socket) do
    case Chat.create_room(%{name: name, description: description}, socket.assigns.current_user.id) do
      {:ok, room} ->
        Phoenix.PubSub.broadcast(BlitzChat.PubSub, "lobby", {:room_created, room})
        {:noreply, push_navigate(socket, to: ~p"/rooms/#{room.slug}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not create room")}
    end
  end

  @impl true
  def handle_info({:room_created, room}, socket) do
    {:noreply, stream_insert(socket, :rooms, room)}
  end

  defp active_member_count(room_id) do
    case Registry.lookup(BlitzChat.RoomRegistry, room_id) do
      [{_pid, _}] ->
        topic = "room:#{room_id}"
        BlitzChatWeb.Presence.list(topic) |> map_size()
      [] -> 0
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Rooms</h1>
            <p class="text-sm text-gray-500">Welcome, {@current_user.display_name}</p>
          </div>
          <div class="flex items-center gap-3">
            <a href={~p"/admin"} class="btn btn-ghost btn-sm rounded-none text-gray-500">Admin</a>
            <button class="btn btn-neutral btn-sm rounded-none" onclick="create_room_modal.showModal()">
              New Room
            </button>
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" id="rooms" phx-update="stream">
          <div :for={{dom_id, room} <- @streams.rooms} id={dom_id}>
            <.link navigate={~p"/rooms/#{room.slug}"} class="block border border-gray-200 p-4 hover:border-gray-400 transition-colors">
              <h3 class="font-semibold text-gray-900">{room.name}</h3>
              <p class="text-sm text-gray-500 mt-1 line-clamp-2">{room.description}</p>
              <div class="flex items-center gap-2 mt-3 text-xs text-gray-400">
                <span class="inline-block w-2 h-2 bg-green-500 rounded-full"></span>
                <span>{active_member_count(room.id)} online</span>
              </div>
            </.link>
          </div>
        </div>

        <dialog id="create_room_modal" class="modal">
          <div class="modal-box rounded-none border border-gray-200">
            <h3 class="text-lg font-bold text-gray-900">Create Room</h3>
            <form phx-submit="create_room" class="space-y-4 mt-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Room Name</label>
                <input type="text" name="name" required maxlength="100" class="input input-bordered w-full rounded-none" placeholder="Engineering" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea name="description" rows="2" class="textarea textarea-bordered w-full rounded-none" placeholder="What's this room about?"></textarea>
              </div>
              <div class="flex justify-end gap-2">
                <button type="button" class="btn btn-ghost btn-sm rounded-none" onclick="create_room_modal.close()">Cancel</button>
                <button type="submit" class="btn btn-neutral btn-sm rounded-none" onclick="create_room_modal.close()">Create</button>
              </div>
            </form>
          </div>
          <form method="dialog" class="modal-backdrop"><button>close</button></form>
        </dialog>
      </div>
    </Layouts.app>
    """
  end
end
