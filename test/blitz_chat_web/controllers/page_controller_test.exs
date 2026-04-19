defmodule BlitzChatWeb.PageControllerTest do
  use BlitzChatWeb.ConnCase, async: true

  test "GET / redirects to /login when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/login"
  end
end
