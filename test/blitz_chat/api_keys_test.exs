defmodule BlitzChat.ApiKeysTest do
  use BlitzChat.DataCase, async: true

  alias BlitzChat.{Accounts, ApiKeys}

  defp user_fixture(attrs \\ %{}) do
    defaults = %{
      username: "u#{System.unique_integer([:positive])}",
      display_name: "Test User"
    }

    {:ok, user} = Accounts.create_user(Map.merge(defaults, attrs))
    user
  end

  describe "create_key/2" do
    test "returns {:ok, api_key, raw_key} with user_id set from explicit arg (no mass-assignment)" do
      owner = user_fixture()
      attacker = user_fixture()

      {:ok, api_key, raw_key} =
        ApiKeys.create_key(%{label: "test", user_id: attacker.id}, owner.id)

      assert api_key.user_id == owner.id
      assert is_binary(raw_key)
      assert String.length(raw_key) > 30
      assert api_key.key_prefix == String.slice(raw_key, 0, 8)
      refute api_key.key_hash == raw_key
    end

    test "validates scopes subset" do
      {:ok, _, _} = ApiKeys.create_key(%{label: "ok", scopes: ["read", "write"]})

      assert {:error, cs} =
               ApiKeys.create_key(%{label: "bad", scopes: ["read", "hackhack"]})

      assert %{scopes: _} = errors_on(cs)
    end

    test "default scopes to [\"read\"]" do
      {:ok, key, _raw} = ApiKeys.create_key(%{label: "no scopes"})
      assert key.scopes == ["read"]
    end
  end

  describe "verify_key/1" do
    test "returns {:ok, key} for active, unexpired key" do
      owner = user_fixture()
      {:ok, _, raw} = ApiKeys.create_key(%{label: "k"}, owner.id)

      assert {:ok, loaded} = ApiKeys.verify_key(raw)
      assert loaded.user_id == owner.id
    end

    test "returns :error for revoked key" do
      {:ok, key, raw} = ApiKeys.create_key(%{label: "k"})
      {:ok, _} = ApiKeys.revoke_key(key.id)

      assert ApiKeys.verify_key(raw) == :error
    end

    test "returns :error for expired key" do
      past = DateTime.utc_now() |> DateTime.add(-3600, :second)
      {:ok, _, raw} = ApiKeys.create_key(%{label: "k", expires_at: past})

      assert ApiKeys.verify_key(raw) == :error
    end

    test "returns :error for unknown key" do
      assert ApiKeys.verify_key("garbage_key_not_in_db") == :error
    end
  end

  describe "touch_last_used/1" do
    test "updates last_used_at" do
      {:ok, key, _raw} = ApiKeys.create_key(%{label: "k"})
      assert key.last_used_at == nil

      {1, _} = ApiKeys.touch_last_used(key.id)

      reloaded = Repo.get!(BlitzChat.ApiKeys.ApiKey, key.id)
      assert reloaded.last_used_at != nil
    end
  end
end
