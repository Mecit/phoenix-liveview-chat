defmodule Oneoffchat.Chat.RoomMonitor do
  @moduledoc """
  A GenServer that subscribes to all chat room presence topics and creates system messages
  whenever users join or leave. This allows us to have a complete history of presence
  events in the chat logs.
  """
  use GenServer
  alias Oneoffchat.Chat

  @available_rooms ["general", "chill", "dev"]

  # --- Client API ---
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- Server Callbacks ---
  @impl true
  def init(_opts) do
    # Loop through and subscribe the monitor to all rooms.
    Enum.each(@available_rooms, fn room ->
      Phoenix.PubSub.subscribe(Oneoffchat.PubSub, "chat:#{room}")
    end)

    {:ok, %{}}
  end

  # We extract the specific room name directly from the topic string!
  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "chat:" <> room, event: "presence_diff", payload: diff},
        state
      ) do

    # Filter out metadata updates (like typing indicators)
    # If a user is in both lists, they just updated their state. We drop them.
    true_joins = Map.drop(diff.joins, Map.keys(diff.leaves))
    true_leaves = Map.drop(diff.leaves, Map.keys(diff.joins))

    # Process the TRUE joins
    for {username, _meta} <- true_joins do
      msg_attrs = %{
        type: :join,
        username: username,
        room: room
      }

      {:ok, message} = Chat.create_message(msg_attrs)
      Phoenix.PubSub.broadcast(Oneoffchat.PubSub, "chat:#{room}", {:new_message, message})
    end

    # Process the TRUE leaves
    for {username, _meta} <- true_leaves do
      msg_attrs = %{
        type: :leave,
        username: username,
        room: room
      }

      {:ok, message} = Chat.create_message(msg_attrs)
      Phoenix.PubSub.broadcast(Oneoffchat.PubSub, "chat:#{room}", {:new_message, message})

      # Broadcast a global disconnect event for any active DMs to catch
      Phoenix.PubSub.broadcast(Oneoffchat.PubSub, "system:presence", {:user_left, username})
    end

    {:noreply, state}
  end

  # Ignore standard chat messages so this process doesn't get noisy
  @impl true
  def handle_info({:new_message, _msg}, state), do: {:noreply, state}
  def handle_info(_, state), do: {:noreply, state}
end
