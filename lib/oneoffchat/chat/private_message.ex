defmodule Oneoffchat.Chat.PrivateMessage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "private_messages" do
    field :username, :string
    field :receiver, :string
    field :text, :string
    field :type, Ecto.Enum, values: [:chat_msg], virtual: true, default: :chat_msg

    field :is_historical, :boolean, virtual: true, default: false

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(private_message, attrs) do
    private_message
    |> cast(attrs, [:text, :username, :receiver])
    |> validate_required([:text, :username, :receiver])
  end
end
