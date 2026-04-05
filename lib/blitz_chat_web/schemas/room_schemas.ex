defmodule BlitzChatWeb.Schemas.RoomRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "RoomRequest",
    type: :object,
    required: [:name],
    properties: %{
      name: %Schema{type: :string, maxLength: 100},
      description: %Schema{type: :string}
    }
  })
end

defmodule BlitzChatWeb.Schemas.RoomResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "RoomResponse",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      name: %Schema{type: :string},
      slug: %Schema{type: :string},
      description: %Schema{type: :string},
      max_members: %Schema{type: :integer},
      is_archived: %Schema{type: :boolean},
      inserted_at: %Schema{type: :string, format: :"date-time"}
    }
  })
end

defmodule BlitzChatWeb.Schemas.RoomListResponse do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "RoomListResponse",
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :array,
        items: BlitzChatWeb.Schemas.RoomResponse
      }
    }
  })
end

defmodule BlitzChatWeb.Schemas.StatsResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StatsResponse",
    type: :object,
    properties: %{
      room_id: %Schema{type: :string, format: :uuid},
      room_slug: %Schema{type: :string},
      total_messages: %Schema{type: :integer},
      buffer_size: %Schema{type: :integer},
      memory: %Schema{type: :integer}
    }
  })
end
