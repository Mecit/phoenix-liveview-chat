defmodule Oneoffchat.Chat.RoomState do
  @moduledoc """
  Manages the state of chat rooms for unread messages and mentions.
  """
  def add_mention(unreads, room, is_mention?) do
    current = Map.get(unreads, room, %{unread: false, mentions: 0})
    new_mentions = if is_mention?, do: current.mentions + 1, else: current.mentions

    Map.put(unreads, room, %{unread: true, mentions: new_mentions})
  end

  def clear_room(unreads, room) do
    Map.put(unreads, room, %{unread: false, mentions: 0})
  end

  def total_mentions(unreads) do
    Enum.reduce(unreads, 0, fn {_room, status}, acc -> acc + status.mentions end)
  end
end
