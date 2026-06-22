defmodule Oneoffchat.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @message_types [:chat_msg, :system, :join, :leave, :emote, :kick, :ban]

  schema "messages" do
    field :type, Ecto.Enum, values: @message_types, default: :chat_msg
    field :username, :string
    field :text, :string
    field :room, :string
    field :is_historical, :boolean, virtual: true, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:type, :username, :text, :room])
    |> validate_required([:type, :room])
    |> validate_message_requirements()
  end

  defp validate_message_requirements(changeset) do
    case get_field(changeset, :type) do
      :chat_msg ->
        changeset
        |> validate_required([:username, :text])
        |> validate_length(:text,
          max: 300,
          message: "Message cannot be longer than 300 characters"
        )

      :system ->
        validate_required(changeset, [:text])

      :join ->
        validate_required(changeset, [:username])

      :leave ->
        validate_required(changeset, [:username])

      _ ->
        changeset
    end
  end
end
