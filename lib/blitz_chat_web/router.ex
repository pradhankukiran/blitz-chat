defmodule BlitzChatWeb.Router do
  use BlitzChatWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BlitzChatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug BlitzChatWeb.Plugs.SetCurrentUser
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: BlitzChatWeb.ApiSpec
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: BlitzChatWeb.ApiSpec
    plug BlitzChatWeb.Plugs.ApiKeyAuth, scope: :read
  end

  pipeline :api_auth_write do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: BlitzChatWeb.ApiSpec
    plug BlitzChatWeb.Plugs.ApiKeyAuth, scope: :write
  end

  scope "/", BlitzChatWeb do
    pipe_through :browser

    live_session :default, on_mount: BlitzChatWeb.LiveAuth do
      live "/", LobbyLive, :index
      live "/rooms/:slug", RoomLive, :show
    end

    live_session :admin,
      on_mount: [BlitzChatWeb.LiveAuth, {BlitzChatWeb.LiveAuth, :ensure_admin}] do
      live "/admin", AdminDashboardLive, :index
    end

    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete
  end

  # REST API (versioned) — read endpoints
  scope "/api/v1", BlitzChatWeb.Api do
    pipe_through :api_auth

    resources "/rooms", RoomController, only: [:index, :show]
    get "/rooms/:room_id/stats", RoomController, :stats
    get "/rooms/:room_id/messages", MessageController, :index
  end

  # REST API (versioned) — write endpoints
  scope "/api/v1", BlitzChatWeb.Api do
    pipe_through :api_auth_write

    post "/rooms", RoomController, :create
    post "/rooms/:room_id/messages", MessageController, :create
  end

  # OpenAPI spec and Swagger UI (gated; enable in non-prod via :expose_swagger config)
  if Application.compile_env(:blitz_chat, :expose_swagger, false) do
    scope "/api" do
      pipe_through :api
      get "/openapi", OpenApiSpex.Plug.RenderSpec, []
    end

    scope "/swaggerui" do
      pipe_through :browser
      get "/", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
    end
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:blitz_chat, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BlitzChatWeb.Telemetry
    end
  end
end
