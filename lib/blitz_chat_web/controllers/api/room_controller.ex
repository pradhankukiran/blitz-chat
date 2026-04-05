defmodule BlitzChatWeb.Api.RoomController do
  use BlitzChatWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias BlitzChat.Chat
  alias BlitzChat.Chat.RoomSupervisor

  tags ["Rooms"]
  security [%{"bearer" => []}]

  operation :index,
    summary: "List all rooms",
    responses: [ok: {"Room list", "application/json", BlitzChatWeb.Schemas.RoomListResponse}]

  def index(conn, _params) do
    rooms = Chat.list_rooms()
    json(conn, %{data: Enum.map(rooms, &room_json/1)})
  end

  operation :show,
    summary: "Get a room",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [ok: {"Room", "application/json", BlitzChatWeb.Schemas.RoomResponse}]

  def show(conn, %{"id" => id}) do
    room = Chat.get_room!(id)
    json(conn, %{data: room_json(room)})
  end

  operation :create,
    summary: "Create a room",
    request_body: {"Room params", "application/json", BlitzChatWeb.Schemas.RoomRequest},
    responses: [
      created: {"Room", "application/json", BlitzChatWeb.Schemas.RoomResponse},
      unprocessable_entity: {"Error", "application/json", nil}
    ]

  def create(conn, params) do
    case Chat.create_room(params) do
      {:ok, room} ->
        Phoenix.PubSub.broadcast(BlitzChat.PubSub, "lobby", {:room_created, room})

        conn
        |> put_status(:created)
        |> json(%{data: room_json(room)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  operation :stats,
    summary: "Get live room stats",
    parameters: [room_id: [in: :path, type: :string, required: true]],
    responses: [ok: {"Stats", "application/json", BlitzChatWeb.Schemas.StatsResponse}]

  def stats(conn, %{"room_id" => room_id}) do
    case RoomSupervisor.ensure_room_started(room_id) do
      {:ok, _pid} ->
        stats = Chat.RoomServer.get_stats(room_id)
        json(conn, %{data: stats})

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Room not found"})
    end
  end

  defp room_json(room) do
    %{
      id: room.id,
      name: room.name,
      slug: room.slug,
      description: room.description,
      max_members: room.max_members,
      is_archived: room.is_archived,
      inserted_at: room.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
