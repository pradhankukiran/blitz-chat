defmodule BlitzChatWeb.Api.RoomController do
  use BlitzChatWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias BlitzChat.Chat
  alias BlitzChat.Chat.RoomSupervisor

  action_fallback BlitzChatWeb.Api.FallbackController

  plug BlitzChatWeb.Plugs.RateLimit,
       [bucket: "api_room_create", limit: 10, window_ms: 60_000]
       when action == :create

  tags ["Rooms"]
  security [%{"bearer" => []}]

  operation :index,
    summary: "List all rooms",
    responses: [ok: {"Room list", "application/json", BlitzChatWeb.Schemas.RoomListResponse}]

  def index(conn, params) do
    with {:ok, opts} <- paginate_opts(params) do
      rooms = Chat.list_rooms(opts)
      json(conn, %{data: Enum.map(rooms, &room_json/1)})
    end
  end

  operation :show,
    summary: "Get a room",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Room", "application/json", BlitzChatWeb.Schemas.RoomResponse},
      not_found: {"Error", "application/json", nil}
    ]

  def show(conn, %{"id" => id}) do
    case Chat.get_room(id) do
      nil -> {:error, :not_found}
      room -> json(conn, %{data: room_json(room)})
    end
  end

  operation :create,
    summary: "Create a room",
    request_body: {"Room params", "application/json", BlitzChatWeb.Schemas.RoomRequest},
    responses: [
      created: {"Room", "application/json", BlitzChatWeb.Schemas.RoomResponse},
      forbidden: {"Error", "application/json", nil},
      unprocessable_entity: {"Error", "application/json", nil}
    ]

  def create(conn, params) do
    with user_id when not is_nil(user_id) <- conn.assigns.api_key.user_id,
         {:ok, room} <- Chat.create_room(params, user_id) do
      Phoenix.PubSub.broadcast(BlitzChat.PubSub, "lobby", {:room_created, room})

      conn
      |> put_status(:created)
      |> json(%{data: room_json(room)})
    else
      nil -> {:error, :forbidden}
      {:error, _} = err -> err
    end
  end

  operation :stats,
    summary: "Get live room stats",
    parameters: [room_id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Stats", "application/json", BlitzChatWeb.Schemas.StatsResponse},
      not_found: {"Error", "application/json", nil}
    ]

  def stats(conn, %{"room_id" => room_id}) do
    case Chat.get_room(room_id) do
      nil ->
        {:error, :not_found}

      _ ->
        {:ok, _pid} = RoomSupervisor.ensure_room_started(room_id)
        stats = Chat.RoomServer.get_stats(room_id)
        json(conn, %{data: stats})
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

  defp paginate_opts(params) do
    with {:ok, limit} <- parse_int(params, "limit", 50, 1, 100),
         {:ok, offset} <- parse_int(params, "offset", 0, 0, 1_000_000) do
      {:ok, [limit: limit, offset: offset]}
    end
  end

  defp parse_int(params, key, default, min, max) do
    case Map.get(params, key) do
      nil ->
        {:ok, default}

      val when is_integer(val) ->
        {:ok, val |> max(min) |> min(max)}

      val when is_binary(val) ->
        case Integer.parse(val) do
          {n, ""} -> {:ok, n |> max(min) |> min(max)}
          _ -> {:error, :invalid_params}
        end

      _ ->
        {:error, :invalid_params}
    end
  end
end
