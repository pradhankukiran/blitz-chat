defmodule BlitzChatWeb.HealthControllerTest do
  use BlitzChatWeb.ConnCase, async: true

  test "GET /health returns 200 ok", %{conn: conn} do
    conn = get(conn, "/health")
    assert response(conn, 200) == "ok"
  end

  test "GET /ready returns 200 when DB and RoomSupervisor alive", %{conn: conn} do
    conn = get(conn, "/ready")
    assert response(conn, 200) == "ok"
  end
end
