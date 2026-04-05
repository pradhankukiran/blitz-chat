defmodule BlitzChatWeb.LiveAuth do
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    user_id = session["current_user_id"]

    if user_id do
      user = BlitzChat.Accounts.get_user!(user_id)
      {:cont, assign(socket, :current_user, user)}
    else
      {:halt, redirect(socket, to: "/login")}
    end
  rescue
    Ecto.NoResultsError ->
      {:halt, redirect(socket, to: "/login")}
  end
end
