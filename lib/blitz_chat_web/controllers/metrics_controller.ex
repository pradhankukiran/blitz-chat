defmodule BlitzChatWeb.MetricsController do
  use BlitzChatWeb, :controller

  def scrape(conn, _params) do
    metrics = TelemetryMetricsPrometheus.Core.scrape()

    conn
    |> put_resp_content_type("text/plain; version=0.0.4; charset=utf-8")
    |> send_resp(200, metrics)
  end
end
