defmodule BlitzChatWeb.Plugs.SetCurrentUser do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :current_user_id)

    if user_id do
      user = BlitzChat.Accounts.get_user!(user_id)
      assign(conn, :current_user, user)
    else
      assign(conn, :current_user, nil)
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> delete_session(:current_user_id)
      |> assign(:current_user, nil)
  end
end
