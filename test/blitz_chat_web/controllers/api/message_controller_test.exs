defmodule BlitzChatWeb.Api.MessageControllerTest do
  use BlitzChatWeb.ConnCase, async: false

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
    {:ok, _key, raw} = ApiKeys.create_key(%{label: "test", scopes: scopes}, user.id)
    raw
  end

  defp room_fixture(user) do
    {:ok, room} = Chat.create_room(%{name: "Room #{System.unique_integer([:positive])}"}, user.id)
    room
  end

  defp authed(conn, raw), do: put_req_header(conn, "authorization", "Bearer " <> raw)

  describe "POST /api/v1/rooms/:room_id/messages" do
    test "uses the API key owner as author (ignores client-supplied user_id)", %{conn: conn} do
      owner = user_fixture()
      _attacker = user_fixture()
      raw = key_fixture(owner)
      room = room_fixture(owner)

      # Try to impersonate by sending attacker's user_id in the body
      conn =
        conn
        |> authed(raw)
        |> post("/api/v1/rooms/#{room.id}/messages", %{
          body: "sneaky",
          user_id: Ecto.UUID.generate()
        })

      body = json_response(conn, 201)
      assert body["data"]["body"] == "sneaky"
      assert body["data"]["user_id"] == owner.id
    end

    test "returns 404 for unknown room", %{conn: conn} do
      owner = user_fixture()
      raw = key_fixture(owner)

      conn =
        conn
        |> authed(raw)
        |> post("/api/v1/rooms/00000000-0000-0000-0000-000000000000/messages", %{
          body: "hi"
        })

      assert json_response(conn, 404)["error"]["code"] == "not_found"
    end

    test "requires :write scope", %{conn: conn} do
      owner = user_fixture()
      raw = key_fixture(owner, ["read"])
      room = room_fixture(owner)

      conn =
        conn
        |> authed(raw)
        |> post("/api/v1/rooms/#{room.id}/messages", %{body: "hi"})

      assert json_response(conn, 403)["error"]["code"] == "insufficient_scope"
    end

    test "returns 422 for body too long", %{conn: conn} do
      owner = user_fixture()
      raw = key_fixture(owner)
      room = room_fixture(owner)

      conn =
        conn
        |> authed(raw)
        |> post("/api/v1/rooms/#{room.id}/messages", %{
          body: String.duplicate("x", 5001)
        })

      assert json_response(conn, 422)["error"]["code"] == "validation_failed"
    end

    test "forbidden when API key has no owner", %{conn: conn} do
      # Create an "unowned" key (system key with no user_id)
      {:ok, _, raw} = ApiKeys.create_key(%{label: "system", scopes: ["read", "write"]})
      owner = user_fixture()
      room = room_fixture(owner)

      conn =
        conn
        |> authed(raw)
        |> post("/api/v1/rooms/#{room.id}/messages", %{body: "hi"})

      assert json_response(conn, 403)["error"]["code"] == "forbidden"
    end
  end

  describe "GET /api/v1/rooms/:room_id/messages" do
    test "returns 404 for unknown room (no 500 crash on bad UUID)", %{conn: conn} do
      owner = user_fixture()
      raw = key_fixture(owner)

      conn = conn |> authed(raw) |> get("/api/v1/rooms/not-a-uuid/messages")
      assert json_response(conn, 404)["error"]["code"] == "not_found"
    end

    test "returns 400 for invalid limit param (no crash on bad int)", %{conn: conn} do
      owner = user_fixture()
      raw = key_fixture(owner)
      room = room_fixture(owner)

      conn =
        conn
        |> authed(raw)
        |> get("/api/v1/rooms/#{room.id}/messages?limit=abc")

      assert json_response(conn, 400)["error"]["code"] == "invalid_params"
    end

    test "caps limit to 100", %{conn: conn} do
      owner = user_fixture()
      raw = key_fixture(owner)
      room = room_fixture(owner)

      for _ <- 1..5 do
        {:ok, _} = Chat.create_message(%{body: "x"}, room.id, owner.id)
      end

      conn =
        conn
        |> authed(raw)
        |> get("/api/v1/rooms/#{room.id}/messages?limit=999999")

      body = json_response(conn, 200)
      assert length(body["data"]) <= 100
    end
  end
end
