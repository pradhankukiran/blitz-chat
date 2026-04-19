defmodule BlitzChatWeb.Api.MessageController do
  use BlitzChatWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias BlitzChat.Chat
  alias BlitzChat.Chat.RoomSupervisor

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
    responses: [ok: {"Message list", "application/json", BlitzChatWeb.Schemas.MessageListResponse}]

  def index(conn, %{"room_id" => room_id} = params) do
    opts = [limit: Map.get(params, "limit", "50") |> String.to_integer()]

    opts =
      case Map.get(params, "before") do
        nil -> opts
        before -> [{:before, before} | opts]
      end

    messages = Chat.list_messages(room_id, opts)
    json(conn, %{data: Enum.map(messages, &message_json/1)})
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
    user_id = conn.assigns.api_key.user_id

    cond do
      is_nil(user_id) ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "API key must be associated with a user"})

      is_nil(Chat.get_room(room_id)) ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Room not found"})

      true ->
        RoomSupervisor.ensure_room_started(room_id)

        case Chat.RoomServer.send_message(room_id, user_id, body) do
          {:ok, message} ->
            conn
            |> put_status(:created)
            |> json(%{data: message_json(message)})

          {:error, :body_too_long} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Message body exceeds 5000 characters"})

          {:error, :empty_body} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Message body cannot be empty"})

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
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
