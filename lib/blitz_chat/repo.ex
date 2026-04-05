defmodule BlitzChat.Repo do
  use Ecto.Repo,
    otp_app: :blitz_chat,
    adapter: Ecto.Adapters.Postgres
end
