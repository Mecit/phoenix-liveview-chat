defmodule OneoffchatWeb.PageController do
  use OneoffchatWeb, :controller

  def privacy(conn, _params) do
    render(conn, :privacy, page_title: "Privacy Policy • OneOffChat")
  end

  def tos(conn, _params) do
    render(conn, :tos, page_title: "Terms of Service • OneOffChat")
  end
end
