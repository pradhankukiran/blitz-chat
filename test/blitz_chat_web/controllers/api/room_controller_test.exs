defmodule BlitzChatWeb.Api.RoomControllerTest do
  use BlitzChatWeb.ConnCase, async: true

  alias BlitzChat.{Accounts, ApiKeys, Chat}

  defp user_fixture do
    {:ok, user} =
      Accounts.create_user(%{
        username: "u#{System.unique_integer([:positive])}",
        display_name: "t"
      })

    user
  end

  defp key_fixture(user, scopes \\ ["read", "write"]) do
    {:ok, _key, raw} =
      ApiKeys.create_key(%{label: "test", scopes: scopes}, user.id)

    raw
  end

  defp authed(conn, raw_key) do
    put_req_header(conn, "authorization", "Bearer " <> raw_key)
  end

  describe "GET /api/v1/rooms" do
    test "requires a valid API key", %{conn: conn} do
      conn = get(conn, "/api/v1/rooms")
      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end

    test "rejects key without :read scope", %{conn: conn} do
      user = user_fixture()
      raw = key_fixture(user, ["write"])

      conn = conn |> authed(raw) |> get("/api/v1/rooms")
      assert json_response(conn, 403)["error"]["code"] == "insufficient_scope"
    end

    test "lists rooms for valid key", %{conn: conn} do
      user = user_fixture()
      raw = key_fixture(user)
      {:ok, _} = Chat.create_room(%{name: "Only Room"}, user.id)

      conn = conn |> authed(raw) |> get("/api/v1/rooms")
      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert Enum.any?(body["data"], &(&1["name"] == "Only Room"))
    end
  end

  describe "POST /api/v1/rooms" do
    test "requires :write scope (read-only key forbidden)", %{conn: conn} do
      user = user_fixture()
      raw = key_fixture(user, ["read"])

      conn =
        conn |> authed(raw) |> post("/api/v1/rooms", %{name: "test"})

      assert json_response(conn, 403)["error"]["code"] == "insufficient_scope"
    end

    test "creates a room with created_by from the API key owner", %{conn: conn} do
      user = user_fixture()
      raw = key_fixture(user)

      conn = conn |> authed(raw) |> post("/api/v1/rooms", %{name: "Via API"})
      body = json_response(conn, 201)

      assert body["data"]["name"] == "Via API"
      assert body["data"]["slug"] == "via-api"

      [room] = BlitzChat.Repo.all(BlitzChat.Chat.Room)
      assert room.created_by == user.id
    end

    test "returns 422 with validation errors on invalid input", %{conn: conn} do
      user = user_fixture()
      raw = key_fixture(user)

      conn = conn |> authed(raw) |> post("/api/v1/rooms", %{name: ""})
      body = json_response(conn, 422)
      assert body["error"]["code"] == "validation_failed"
      assert is_map(body["error"]["details"])
    end
  end

  describe "GET /api/v1/rooms/:id" do
    test "returns 404 for unknown room (envelope format)", %{conn: conn} do
      user = user_fixture()
      raw = key_fixture(user)

      conn =
        conn
        |> authed(raw)
        |> get("/api/v1/rooms/00000000-0000-0000-0000-000000000000")

      body = json_response(conn, 404)
      assert body["error"]["code"] == "not_found"
    end

    test "returns 404 for invalid UUID (doesn't crash)", %{conn: conn} do
      user = user_fixture()
      raw = key_fixture(user)

      conn = conn |> authed(raw) |> get("/api/v1/rooms/not-a-uuid")
      assert json_response(conn, 404)["error"]["code"] == "not_found"
    end
  end
end
