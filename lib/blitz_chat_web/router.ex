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
  end

  scope "/", BlitzChatWeb do
    pipe_through :browser

    live_session :default, on_mount: BlitzChatWeb.LiveAuth do
      live "/", LobbyLive, :index
      live "/rooms/:slug", RoomLive, :show
      live "/admin", AdminDashboardLive, :index
    end

    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete
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
