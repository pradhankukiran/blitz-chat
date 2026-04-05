defmodule BlitzChatWeb.Api.MessageController do
  use BlitzChatWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias BlitzChat.Chat
  alias BlitzChat.Chat.RoomSupervisor

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
      unprocessable_entity: {"Error", "application/json", nil}
    ]

  def create(conn, %{"room_id" => room_id, "body" => body, "user_id" => user_id}) do
    RoomSupervisor.ensure_room_started(room_id)
    Chat.RoomServer.send_message(room_id, user_id, body)

    conn
    |> put_status(:created)
    |> json(%{data: %{status: "sent", room_id: room_id}})
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
