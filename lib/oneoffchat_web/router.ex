defmodule OneoffchatWeb.Router do
  use OneoffchatWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OneoffchatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :assign_device_id
    plug OneoffchatWeb.Plugs.BanCheck
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OneoffchatWeb do
    pipe_through :browser

    live "/", ChatLive
    get "/privacy", PageController, :privacy
    get "/tos", PageController, :tos
  end

  defp assign_device_id(conn, _opts) do
    if get_session(conn, :device_id) do
      conn
    else
      # If they don't have one, give them a random UUID
      put_session(conn, :device_id, Ecto.UUID.generate())
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", OneoffchatWeb do
  #   pipe_through :api
  # end
end
