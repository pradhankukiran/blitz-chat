defmodule BlitzChatWeb.Plugs.RateLimit do
  @moduledoc false
  import Plug.Conn

  def init(opts) do
    %{
      bucket: Keyword.fetch!(opts, :bucket),
      limit: Keyword.fetch!(opts, :limit),
      window_ms: Keyword.fetch!(opts, :window_ms),
      key_fn: Keyword.get(opts, :key_fn, &default_key/1)
    }
  end

  def call(conn, %{bucket: bucket, limit: limit, window_ms: window_ms, key_fn: key_fn}) do
    full_key = "#{bucket}:#{key_fn.(conn)}"

    case Hammer.check_rate(full_key, window_ms, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(div(window_ms, 1000)))
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.json(%{error: "Rate limit exceeded"})
        |> halt()
    end
  end

  def check(bucket, key, limit, window_ms) do
    Hammer.check_rate("#{bucket}:#{key}", window_ms, limit)
  end

  defp default_key(conn) do
    case conn.assigns[:api_key] do
      %{id: id} -> "key:#{id}"
      _ -> "ip:#{format_ip(conn.remote_ip)}"
    end
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_ip({a, b, c, d, e, f, g, h}), do: "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
  defp format_ip(_), do: "unknown"
end
