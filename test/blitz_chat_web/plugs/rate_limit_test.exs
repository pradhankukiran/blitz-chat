defmodule BlitzChatWeb.Plugs.RateLimitTest do
  use ExUnit.Case, async: false
  import Plug.Test

  alias BlitzChatWeb.Plugs.RateLimit

  setup do
    # Scrub hammer state by using unique bucket names per test
    bucket = "test_bucket_#{System.unique_integer([:positive])}"
    %{bucket: bucket}
  end

  test "allows requests under the limit", %{bucket: bucket} do
    opts = RateLimit.init(bucket: bucket, limit: 3, window_ms: 60_000)

    for _ <- 1..3 do
      conn = conn(:post, "/foo") |> Map.put(:remote_ip, {1, 2, 3, 4})
      conn = RateLimit.call(conn, opts)
      refute conn.halted
    end
  end

  test "halts with 429 when over the limit", %{bucket: bucket} do
    opts = RateLimit.init(bucket: bucket, limit: 2, window_ms: 60_000)

    for _ <- 1..2 do
      conn(:post, "/foo")
      |> Map.put(:remote_ip, {1, 2, 3, 4})
      |> RateLimit.call(opts)
    end

    conn = conn(:post, "/foo") |> Map.put(:remote_ip, {1, 2, 3, 4}) |> RateLimit.call(opts)
    assert conn.halted
    assert conn.status == 429
    assert Enum.any?(conn.resp_headers, fn {k, _} -> k == "retry-after" end)
  end

  test "different IPs have independent buckets", %{bucket: bucket} do
    opts = RateLimit.init(bucket: bucket, limit: 1, window_ms: 60_000)

    conn1 =
      conn(:post, "/foo") |> Map.put(:remote_ip, {1, 2, 3, 4}) |> RateLimit.call(opts)

    conn2 =
      conn(:post, "/foo") |> Map.put(:remote_ip, {5, 6, 7, 8}) |> RateLimit.call(opts)

    refute conn1.halted
    refute conn2.halted
  end

  test "check/4 returns :allow and :deny tuples", %{bucket: bucket} do
    assert {:allow, 1} = RateLimit.check(bucket, "u1", 2, 60_000)
    assert {:allow, 2} = RateLimit.check(bucket, "u1", 2, 60_000)
    assert {:deny, 2} = RateLimit.check(bucket, "u1", 2, 60_000)
  end
end
