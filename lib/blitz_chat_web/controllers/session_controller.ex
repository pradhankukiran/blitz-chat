defmodule BlitzChatWeb.SessionController do
  use BlitzChatWeb, :controller

  def new(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/")
    else
      render(conn, :new)
    end
  end

  def create(conn, %{"username" => username, "display_name" => display_name}) do
    case BlitzChat.Accounts.get_user_by_username(username) do
      nil ->
        case BlitzChat.Accounts.create_user(%{username: username, display_name: display_name}) do
          {:ok, user} ->
            conn
            |> put_session(:current_user_id, user.id)
            |> redirect(to: ~p"/")

          {:error, changeset} ->
            conn
            |> put_flash(:error, format_errors(changeset))
            |> render(:new)
        end

      user ->
        conn
        |> put_session(:current_user_id, user.id)
        |> redirect(to: ~p"/")
    end
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/login")
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
