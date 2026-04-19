defmodule BlitzChatWeb.ApiSpec do
  alias OpenApiSpex.{Info, OpenApi, Paths, Server, SecurityScheme, Components}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "BlitzChat API",
        version: "1.0.0",
        description: "REST API for BlitzChat — real-time chat powered by BEAM"
      },
      servers: [%Server{url: "/api/v1"}],
      paths: Paths.from_router(BlitzChatWeb.Router),
      components: %Components{
        securitySchemes: %{
          "bearer" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            description: "API key authentication"
          }
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
