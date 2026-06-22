defmodule OneoffchatWeb.ChatterAuth do
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, %{"current_username" => username}, socket) do
    {:cont, assign(socket, current_username: username)}
  end

  def on_mount(:default, _params, _session, socket) do
    # Halt the mount lifecycle and redirect
    {:halt, push_navigate(socket, to: "/")}
  end
end
