defmodule BlitzChatWeb.PageController do
  use BlitzChatWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
