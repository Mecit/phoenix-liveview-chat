defmodule OneoffchatWeb.Plugs.BanCheck do
  import Plug.Conn
  import Phoenix.Controller, only: [put_view: 2, put_root_layout: 2, render: 2]
  alias Oneoffchat.Accounts

  def init(default), do: default

  def call(conn, _opts) do
    # 1. Look for the standard forwarded IP header to match LiveView logic
    ip_address =
      case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
        [forwarded_ips | _] ->
          forwarded_ips
          |> String.split(",")
          |> List.first()
          |> String.trim()

        [] ->
          conn.remote_ip |> :inet_parse.ntoa() |> to_string()
      end
      |> Accounts.normalize_ip()

    if Accounts.ip_banned?(ip_address) do
      conn
      |> put_status(:forbidden)
      |> put_view(OneoffchatWeb.ErrorHTML)
      |> put_root_layout(false)
      |> render("403.html")
      |> halt()
    else
      # Let them pass
      conn
    end
  end
end
