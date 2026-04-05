defmodule BlitzChatWeb.Schemas.MessageRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "MessageRequest",
    type: :object,
    required: [:body, :user_id],
    properties: %{
      body: %Schema{type: :string, maxLength: 5000},
      user_id: %Schema{type: :string, format: :uuid}
    }
  })
end

defmodule BlitzChatWeb.Schemas.MessageResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "MessageResponse",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      body: %Schema{type: :string},
      room_id: %Schema{type: :string, format: :uuid},
      user_id: %Schema{type: :string, format: :uuid},
      user: %Schema{
        type: :object,
        properties: %{
          id: %Schema{type: :string, format: :uuid},
          username: %Schema{type: :string},
          display_name: %Schema{type: :string}
        }
      },
      inserted_at: %Schema{type: :string, format: :"date-time"}
    }
  })
end

defmodule BlitzChatWeb.Schemas.MessageListResponse do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "MessageListResponse",
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :array,
        items: BlitzChatWeb.Schemas.MessageResponse
      }
    }
  })
end
