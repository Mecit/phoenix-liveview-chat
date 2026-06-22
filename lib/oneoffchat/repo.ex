defmodule Oneoffchat.Repo do
  use Ecto.Repo,
    otp_app: :oneoffchat,
    adapter: Ecto.Adapters.SQLite3
end
