defmodule BlitzChatWeb.AdminDashboardLiveTest do
  use BlitzChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BlitzChat.Accounts

  defp user_fixture(attrs \\ %{}) do
    defaults = %{
      username: "u#{System.unique_integer([:positive])}",
      display_name: "Test"
    }

    {:ok, user} = Accounts.create_user(Map.merge(defaults, attrs))
    user
  end

  defp logged_in(conn, user) do
    Plug.Test.init_test_session(conn, current_user_id: user.id)
  end

  test "redirects unauthenticated visitor to /login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/admin")
  end

  test "redirects logged-in non-admin to /", %{conn: conn} do
    user = user_fixture()
    conn = logged_in(conn, user)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/admin")
  end

  test "admin user can access the dashboard", %{conn: conn} do
    {:ok, admin} =
      %Accounts.User{admin: true}
      |> BlitzChat.Accounts.User.changeset(%{
        username: "admin#{System.unique_integer([:positive])}",
        display_name: "Admin"
      })
      |> BlitzChat.Repo.insert()

    conn = logged_in(conn, admin)

    assert {:ok, _view, html} = live(conn, "/admin")
    assert html =~ "Admin Dashboard"
  end
end
