defmodule BlitzChatWeb.Api.MessageController do
  use BlitzChatWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias BlitzChat.Chat
  alias BlitzChat.Chat.RoomSupervisor

  action_fallback BlitzChatWeb.Api.FallbackController

  plug BlitzChatWeb.Plugs.RateLimit,
       [bucket: "api_message_create", limit: 60, window_ms: 60_000]
       when action == :create

  tags ["Messages"]
  security [%{"bearer" => []}]

  operation :index,
    summary: "List messages in a room",
    parameters: [
      room_id: [in: :path, type: :string, required: true],
      limit: [in: :query, type: :integer, required: false],
      before: [in: :query, type: :string, required: false]
    ],
    responses: [
      ok: {"Message list", "application/json", BlitzChatWeb.Schemas.MessageListResponse},
      not_found: {"Error", "application/json", nil}
    ]

  def index(conn, %{"room_id" => room_id} = params) do
    with {:ok, room} <- fetch_room(room_id),
         {:ok, opts} <- build_list_opts(params) do
      messages = Chat.list_messages(room.id, opts)
      json(conn, %{data: Enum.map(messages, &message_json/1)})
    end
  end

  operation :create,
    summary: "Send a message to a room",
    parameters: [room_id: [in: :path, type: :string, required: true]],
    request_body: {"Message params", "application/json", BlitzChatWeb.Schemas.MessageRequest},
    responses: [
      created: {"Message", "application/json", BlitzChatWeb.Schemas.MessageResponse},
      forbidden: {"Error", "application/json", nil},
      not_found: {"Error", "application/json", nil},
      unprocessable_entity: {"Error", "application/json", nil}
    ]

  def create(conn, %{"room_id" => room_id, "body" => body}) do
    with user_id when not is_nil(user_id) <- conn.assigns.api_key.user_id,
         {:ok, room} <- fetch_room(room_id),
         {:ok, _pid} <- RoomSupervisor.ensure_room_started(room.id),
         {:ok, message} <- Chat.RoomServer.send_message(room.id, user_id, body) do
      conn
      |> put_status(:created)
      |> json(%{data: message_json(message)})
    else
      nil -> {:error, :forbidden}
      {:error, _} = err -> err
    end
  end

  defp fetch_room(id) do
    case Chat.get_room(id) do
      nil -> {:error, :not_found}
      room -> {:ok, room}
    end
  end

  defp build_list_opts(params) do
    with {:ok, limit} <- parse_int(params, "limit", 50, 1, 100) do
      opts = [limit: limit]

      case Map.get(params, "before") do
        nil ->
          {:ok, opts}

        before ->
          case DateTime.from_iso8601(before) do
            {:ok, dt, _} -> {:ok, [{:before, dt} | opts]}
            _ -> {:error, :invalid_params}
          end
      end
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

  defp message_json(message) do
    %{
      id: message.id,
      body: message.body,
      room_id: message.room_id,
      user_id: message.user_id,
      user: %{
        id: message.user.id,
        username: message.user.username,
        display_name: message.user.display_name
      },
      inserted_at: message.inserted_at
    }
  end
end
