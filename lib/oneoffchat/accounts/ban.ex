defmodule Oneoffchat.Accounts.Ban do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bans" do
    field :ip_address, :string
    field :username, :string
    field :device_id, :string
    field :reason, :string
    field :banned_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(ban, attrs) do
    ban
    |> cast(attrs, [:ip_address, :username, :device_id, :reason, :banned_at])
    |> validate_required([:ip_address, :reason, :banned_at])
  end
end
