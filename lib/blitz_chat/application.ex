defmodule BlitzChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BlitzChatWeb.Telemetry,
      BlitzChat.Repo,
      {DNSCluster, query: Application.get_env(:blitz_chat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BlitzChat.PubSub},
      {Registry, keys: :unique, name: BlitzChat.RoomRegistry},
      {DynamicSupervisor, name: BlitzChat.Chat.RoomSupervisor, strategy: :one_for_one},
      BlitzChatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BlitzChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BlitzChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
