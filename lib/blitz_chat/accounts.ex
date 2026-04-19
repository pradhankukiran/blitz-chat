defmodule BlitzChat.Accounts do
  import Ecto.Query
  alias BlitzChat.Repo
  alias BlitzChat.Accounts.User

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: String.downcase(username))
  end

  def list_users do
    Repo.all(from u in User, order_by: [asc: u.username])
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
