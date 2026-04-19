defmodule BlitzChatWeb.RoomLive do
  use BlitzChatWeb, :live_view

  alias BlitzChat.Chat
  alias BlitzChat.Chat.RoomSupervisor
  alias BlitzChatWeb.Presence

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    room = Chat.get_room_by_slug!(slug)
    user = socket.assigns.current_user

    if connected?(socket) do
      # Start or find the room GenServer
      RoomSupervisor.ensure_room_started(room.id)

      # Subscribe to room messages
      Phoenix.PubSub.subscribe(BlitzChat.PubSub, "room:#{room.id}")

      # Track presence
      Presence.track(self(), "room:#{room.id}", user.id, %{
        username: user.username,
        display_name: user.display_name,
        typing: false,
        joined_at: System.system_time(:second)
      })

      # Subscribe to presence changes
      Phoenix.PubSub.subscribe(BlitzChat.PubSub, "room_presence:#{room.id}")
    end

    messages = Chat.list_messages(room.id, limit: 50)
    presences = if connected?(socket), do: Presence.list("room:#{room.id}"), else: %{}

    oldest =
      case messages do
        [%{inserted_at: at} | _] -> at
        _ -> nil
      end

    {:ok,
     socket
     |> assign(:page_title, room.name)
     |> assign(:room, room)
     |> assign(:presences, presences)
     |> assign(:typing_users, [])
     |> assign(:oldest_message_at, oldest)
     |> stream(:messages, messages), temporary_assigns: []}
  end

  @impl true
  def handle_event("send_message", %{"body" => body}, socket) do
    body = String.trim(body)

    cond do
      body == "" ->
        {:noreply, socket}

      match?(
        {:deny, _},
        BlitzChatWeb.Plugs.RateLimit.check(
          "lv_send_message",
          socket.assigns.current_user.id,
          30,
          10_000
        )
      ) ->
        {:noreply, put_flash(socket, :error, "You're sending messages too fast")}

      true ->
        case Chat.RoomServer.send_message(
               socket.assigns.room.id,
               socket.assigns.current_user.id,
               body
             ) do
          {:ok, _message} ->
            update_typing(socket, false)
            {:noreply, socket}

          {:error, :body_too_long} ->
            {:noreply, put_flash(socket, :error, "Message too long (max 5000 chars)")}

          {:error, :empty_body} ->
            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Could not send message")}
        end
    end
  end

  @impl true
  def handle_event("typing", _params, socket) do
    update_typing(socket, true)
    if socket.assigns[:typing_timer], do: Process.cancel_timer(socket.assigns[:typing_timer])
    timer = Process.send_after(self(), :clear_typing, 2000)
    {:noreply, assign(socket, :typing_timer, timer)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    case socket.assigns[:oldest_message_at] do
      nil ->
        {:noreply, socket}

      before_ts ->
        older = Chat.list_messages(socket.assigns.room.id, limit: 50, before: before_ts)

        new_oldest =
          case older do
            [%{inserted_at: at} | _] -> at
            _ -> before_ts
          end

        {:noreply,
         socket
         |> assign(:oldest_message_at, new_oldest)
         |> stream(:messages, older, at: 0)}
    end
  end

  @impl true
  def handle_info({:new_message, %BlitzChat.Chat.Message{} = message}, socket) do
    {:noreply, stream_insert(socket, :messages, message, limit: -200)}
  end

  @impl true
  def handle_info(:clear_typing, socket) do
    update_typing(socket, false)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    presences = Presence.list("room:#{socket.assigns.room.id}")

    typing_users =
      presences
      |> Enum.flat_map(fn {_user_id, %{metas: metas}} ->
        Enum.filter(metas, & &1.typing)
        |> Enum.map(& &1.display_name)
      end)
      |> Enum.reject(&(&1 == socket.assigns.current_user.display_name))

    {:noreply, assign(socket, presences: presences, typing_users: typing_users)}
  end

  defp update_typing(socket, typing) do
    user = socket.assigns.current_user

    Presence.update(self(), "room:#{socket.assigns.room.id}", user.id, fn meta ->
      Map.put(meta, :typing, typing)
    end)
  end

  defp presence_list(presences) do
    presences
    |> Enum.flat_map(fn {_user_id, %{metas: [meta | _]}} -> [meta] end)
    |> Enum.sort_by(& &1.display_name)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-white">
      <%!-- Sidebar --%>
      <div class="w-64 border-r border-gray-200 flex flex-col">
        <div class="p-4 border-b border-gray-200">
          <.link navigate={~p"/"} class="text-sm text-gray-500 hover:text-gray-700">
            &larr; Back to Lobby
          </.link>
          <h2 class="text-lg font-bold text-gray-900 mt-2">{@room.name}</h2>
          <p class="text-xs text-gray-500 mt-1">{@room.description}</p>
        </div>

        <div class="flex-1 overflow-y-auto p-4">
          <h3 class="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">
            Online ({map_size(@presences)})
          </h3>
          <ul class="space-y-2">
            <li :for={user <- presence_list(@presences)} class="flex items-center gap-2 text-sm">
              <span class="w-2 h-2 bg-green-500 rounded-full flex-shrink-0"></span>
              <span class="text-gray-700 truncate">{user.display_name}</span>
              <span :if={user.typing} class="text-xs text-gray-400 italic ml-auto">typing...</span>
            </li>
          </ul>
        </div>

        <div class="p-4 border-t border-gray-200">
          <p class="text-sm text-gray-700 font-medium">{@current_user.display_name}</p>
          <p class="text-xs text-gray-400">@{@current_user.username}</p>
        </div>
      </div>

      <%!-- Main chat area --%>
      <div class="flex-1 flex flex-col">
        <%!-- Messages --%>
        <div
          class="flex-1 overflow-y-auto p-4 space-y-3"
          id="messages"
          phx-update="stream"
          phx-hook="ScrollBottom"
        >
          <div :for={{dom_id, message} <- @streams.messages} id={dom_id} class="flex gap-3">
            <div class="flex-shrink-0 w-8 h-8 bg-gray-200 flex items-center justify-center text-xs font-bold text-gray-600">
              {String.first(message.user.display_name)}
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-baseline gap-2">
                <span class="text-sm font-semibold text-gray-900">{message.user.display_name}</span>
                <span class="text-xs text-gray-400">{format_time(message.inserted_at)}</span>
              </div>
              <p class="text-sm text-gray-700 break-words">{message.body}</p>
            </div>
          </div>
        </div>

        <%!-- Typing indicator --%>
        <div :if={@typing_users != []} class="px-4 py-1 text-xs text-gray-400 italic">
          {Enum.join(@typing_users, ", ")} {if length(@typing_users) == 1, do: "is", else: "are"} typing...
        </div>

        <%!-- Input --%>
        <div class="border-t border-gray-200 p-4">
          <form phx-submit="send_message" phx-change="typing" class="flex gap-2">
            <input
              type="text"
              name="body"
              placeholder="Type a message..."
              autocomplete="off"
              class="input input-bordered flex-1 rounded-none"
              autofocus
            />
            <button type="submit" class="btn btn-neutral rounded-none">Send</button>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end
end
