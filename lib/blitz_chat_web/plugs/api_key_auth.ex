defmodule BlitzChatWeb.Plugs.ApiKeyAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> key] <- get_req_header(conn, "authorization"),
         {:ok, api_key} <- BlitzChat.ApiKeys.verify_key(key) do
      assign(conn, :api_key, api_key)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Invalid or missing API key"})
        |> halt()
    end
  end
end
