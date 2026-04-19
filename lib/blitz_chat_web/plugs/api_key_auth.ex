defmodule BlitzChatWeb.Plugs.ApiKeyAuth do
  import Plug.Conn

  def init(opts) do
    %{required_scope: Keyword.get(opts, :scope)}
  end

  def call(conn, %{required_scope: required_scope}) do
    with ["Bearer " <> key] <- get_req_header(conn, "authorization"),
         {:ok, api_key} <- BlitzChat.ApiKeys.verify_key(key),
         :ok <- check_scope(api_key, required_scope) do
      touch_async(api_key.id)
      assign(conn, :api_key, api_key)
    else
      :insufficient_scope -> forbidden(conn, required_scope)
      _ -> unauthorized(conn)
    end
  end

  defp touch_async(id) do
    if Application.get_env(:blitz_chat, :api_key_sync_touch, false) do
      BlitzChat.ApiKeys.touch_last_used(id)
    else
      Task.Supervisor.start_child(BlitzChat.TaskSupervisor, fn ->
        BlitzChat.ApiKeys.touch_last_used(id)
      end)
    end
  end

  defp check_scope(_api_key, nil), do: :ok

  defp check_scope(%{scopes: scopes}, required) when is_list(scopes) do
    required_str = Atom.to_string(required)

    if required_str in scopes or "admin" in scopes,
      do: :ok,
      else: :insufficient_scope
  end

  defp check_scope(_, _), do: :insufficient_scope

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{
      error: %{code: "unauthorized", message: "Invalid or missing API key"}
    })
    |> halt()
  end

  defp forbidden(conn, required_scope) do
    conn
    |> put_status(:forbidden)
    |> Phoenix.Controller.json(%{
      error: %{
        code: "insufficient_scope",
        message: "API key lacks required scope: #{required_scope}"
      }
    })
    |> halt()
  end
end
