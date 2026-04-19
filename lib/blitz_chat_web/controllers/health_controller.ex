defmodule BlitzChatWeb.HealthController do
  use BlitzChatWeb, :controller

  alias BlitzChat.Repo

  def live(conn, _params) do
    send_resp(conn, 200, "ok")
  end

  def ready(conn, _params) do
    checks =
      [db: check_db(), room_supervisor: check_process(BlitzChat.Chat.RoomSupervisor)]

    failed = for {name, {:error, _}} <- checks, do: name

    if failed == [] do
      send_resp(conn, 200, "ok")
    else
      send_resp(conn, 503, "not_ready: #{Enum.join(failed, ",")}")
    end
  end

  defp check_db do
    case Ecto.Adapters.SQL.query(Repo, "SELECT 1", [], timeout: 2_000) do
      {:ok, _} -> {:ok, :db}
      {:error, _} -> {:error, :db}
    end
  rescue
    _ -> {:error, :db}
  end

  defp check_process(name) do
    if Process.whereis(name), do: {:ok, name}, else: {:error, name}
  end
end
