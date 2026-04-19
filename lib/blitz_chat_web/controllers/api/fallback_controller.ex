defmodule BlitzChatWeb.Api.FallbackController do
  use Phoenix.Controller, formats: [:json]

  def call(conn, {:error, :not_found}) do
    conn |> put_status(404) |> json(envelope("not_found", "Resource not found"))
  end

  def call(conn, {:error, :forbidden}) do
    conn |> put_status(403) |> json(envelope("forbidden", "Action not permitted"))
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(401)
    |> json(envelope("unauthorized", "Missing or invalid credentials"))
  end

  def call(conn, {:error, :rate_limited}) do
    conn |> put_status(429) |> json(envelope("rate_limited", "Too many requests"))
  end

  def call(conn, {:error, :body_too_long}) do
    conn
    |> put_status(422)
    |> json(envelope("validation_failed", "Message body exceeds 5000 characters"))
  end

  def call(conn, {:error, :empty_body}) do
    conn
    |> put_status(422)
    |> json(envelope("validation_failed", "Message body cannot be empty"))
  end

  def call(conn, {:error, %Ecto.Changeset{} = cs}) do
    conn
    |> put_status(422)
    |> json(envelope("validation_failed", "Invalid input", changeset_details(cs)))
  end

  def call(conn, {:error, :invalid_params}) do
    conn |> put_status(400) |> json(envelope("invalid_params", "Invalid query parameters"))
  end

  defp envelope(code, message, details \\ nil)
  defp envelope(code, message, nil), do: %{error: %{code: code, message: message}}

  defp envelope(code, message, details),
    do: %{error: %{code: code, message: message, details: details}}

  defp changeset_details(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
