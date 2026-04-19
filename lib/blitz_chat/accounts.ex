defmodule BlitzChat.Accounts do
  import Ecto.Query
  alias BlitzChat.Repo
  alias BlitzChat.Accounts.User

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: String.downcase(username))
  end

  def list_users(opts \\ []) do
    limit = opts |> Keyword.get(:limit, 50) |> min(100) |> max(1)
    offset = opts |> Keyword.get(:offset, 0) |> max(0)

    from(u in User, order_by: [asc: u.username], limit: ^limit, offset: ^offset)
    |> Repo.all()
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
