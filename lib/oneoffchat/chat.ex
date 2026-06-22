defmodule Oneoffchat.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias Oneoffchat.Repo

  alias Oneoffchat.Chat.Message
  alias Oneoffchat.Chat.PrivateMessage

  @doc """
  Returns the most recent messages, ordered by newest first.
  Defaults to 50 messages, but can be overridden.
  """
  def list_recent_messages(room, limit \\ 50) do
    query =
      from m in Message,
        where: m.room == ^room,
        # Ordering by ID instead of inserted_at for consistency
        order_by: [desc: m.id],
        limit: ^limit

    Repo.all(query)
  end

  @doc """
  Creates a new message in the database.
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  # 1. Save a new DM
  def create_private_message(attrs \\ %{}) do
    %PrivateMessage{}
    |> PrivateMessage.changeset(attrs)
    |> Repo.insert()
  end

  # 2. Fetch a two-way conversation history
  def list_private_messages(user_a, user_b) do
    Repo.all(
      from pm in PrivateMessage,
        where:
          (pm.username == ^user_a and pm.receiver == ^user_b) or
            (pm.username == ^user_b and pm.receiver == ^user_a),
        order_by: [asc: pm.inserted_at]
    )
  end
end
