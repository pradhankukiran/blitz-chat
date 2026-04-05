defmodule BlitzChatWeb.Presence do
  use Phoenix.Presence,
    otp_app: :blitz_chat,
    pubsub_server: BlitzChat.PubSub
end
