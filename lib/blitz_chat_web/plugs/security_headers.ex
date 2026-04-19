defmodule BlitzChatWeb.Plugs.SecurityHeaders do
  @moduledoc false
  import Plug.Conn

  @csp """
  default-src 'self'; \
  script-src 'self'; \
  style-src 'self' 'unsafe-inline'; \
  connect-src 'self' ws: wss:; \
  img-src 'self' data:; \
  font-src 'self' data:; \
  frame-ancestors 'none'; \
  base-uri 'self'; \
  form-action 'self'\
  """

  @permissions_policy "camera=(), microphone=(), geolocation=(), payment=(), usb=()"

  @referrer_policy "strict-origin-when-cross-origin"

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("content-security-policy", @csp)
    |> put_resp_header("permissions-policy", @permissions_policy)
    |> put_resp_header("referrer-policy", @referrer_policy)
  end
end
