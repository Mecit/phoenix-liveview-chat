defmodule OneoffchatWeb.ChatLive.CommandHandler do
  alias Oneoffchat.Accounts
  alias OneoffchatWeb.ChatLive
  alias Phoenix.PubSub

  # --------------------------------------------------------
  # BROADCAST COMMANDS & NORMAL MESSAGES
  # --------------------------------------------------------

  # The Bouncer for /system commands
  def execute(
        {:broadcast, :system, _text, _username},
        %{assigns: %{current_chatter: %{is_admin: false}}} = socket
      ) do
    {:noreply,
     ChatLive.prepend_to_active_room(
       socket,
       ChatLive.build_local_error("Unknown command: /system")
     )}
  end

  # Handles both /system broadcasts AND normal :chat_msg messages!
  def execute({:broadcast, type, text, username}, socket) do
    case ChatLive.broadcast_message(%{
           type: type,
           text: text,
           username: username,
           room: socket.assigns.active_room
         }) do
      {:ok, _message} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {_field, {msg, _opts}} = Enum.at(changeset.errors, 0)
        local_error = ChatLive.build_local_error(msg)
        {:noreply, ChatLive.prepend_to_active_room(socket, local_error)}
    end
  end

  # --------------------------------------------------------
  # ADMIN MODERATION COMMANDS
  # --------------------------------------------------------

  # --- KICK COMMANDS ---
  def execute(
        {:admin, :kick, _target, _reason},
        %{assigns: %{current_chatter: %{is_admin: false}}} = socket
      ) do
    {:noreply,
     ChatLive.prepend_to_active_room(socket, ChatLive.build_local_error("Unknown command: /kick"))}
  end

  def execute({:admin, :kick, "", ""}, socket) do
    {:noreply,
     ChatLive.prepend_to_active_room(
       socket,
       ChatLive.build_local_error("Usage: /kick <username> [reason]")
     )}
  end

  def execute({:admin, :kick, target_user, _reason}, socket)
      when socket.assigns.current_chatter.username == target_user do
    {:noreply,
     ChatLive.prepend_to_active_room(
       socket,
       ChatLive.build_local_error("You may not kick yourself.")
     )}
  end

  def execute({:admin, :kick, target_user, reason}, socket) do
    presences = OneoffchatWeb.Presence.list("chat:global")

    case Map.get(presences, target_user) do
      nil ->
        {:noreply,
         ChatLive.prepend_to_active_room(
           socket,
           ChatLive.build_local_error("User '#{target_user}' is not online.")
         )}

      _ ->
        PubSub.broadcast(Oneoffchat.PubSub, "chat:global", {:kick_user, target_user, reason})

        case ChatLive.broadcast_message(%{
               type: :kick,
               text: "#{target_user} was kicked. Reason: #{reason}",
               username: "SYSTEM",
               room: socket.assigns.active_room
             }) do
          {:ok, _message} ->
            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply,
             ChatLive.prepend_to_active_room(
               socket,
               ChatLive.build_local_error("User was kicked, but announcement failed.")
             )}
        end
    end
  end

  # --- BAN COMMANDS ---
  def execute(
        {:admin, :ban, _target, _reason},
        %{assigns: %{current_chatter: %{is_admin: false}}} = socket
      ) do
    {:noreply,
     ChatLive.prepend_to_active_room(socket, ChatLive.build_local_error("Unknown command: /ban"))}
  end

  def execute({:admin, :ban, "", ""}, socket) do
    {:noreply,
     ChatLive.prepend_to_active_room(
       socket,
       ChatLive.build_local_error("Usage: /ban <username> [reason]")
     )}
  end

  def execute({:admin, :ban, target_user, _reason}, socket)
      when socket.assigns.current_chatter.username == target_user do
    {:noreply,
     ChatLive.prepend_to_active_room(
       socket,
       ChatLive.build_local_error("You may not ban yourself.")
     )}
  end

  def execute({:admin, :ban, target_user, reason}, socket) do
    presences = OneoffchatWeb.Presence.list("chat:global")

    case Map.get(presences, target_user) do
      nil ->
        {:noreply,
         ChatLive.prepend_to_active_room(
           socket,
           ChatLive.build_local_error("User '#{target_user}' is not online.")
         )}

      %{metas: [meta | _]} ->
        Accounts.ban_user(%{
          ip_address: meta.ip_address,
          username: target_user,
          device_id: meta.device_id,
          reason: reason,
          banned_at: DateTime.utc_now()
        })

        PubSub.broadcast(
          Oneoffchat.PubSub,
          "chat:global",
          {:kick_user, target_user, "BANNED: #{reason}"}
        )

        ChatLive.broadcast_message(%{
          type: :ban,
          text: "#{target_user} was banned. Reason: #{reason}",
          username: "SYSTEM",
          room: socket.assigns.active_room
        })

        {:noreply, socket}
    end
  end

  # --- UNBAN COMMANDS ---
  def execute(
        {:admin, :unban, _target},
        %{assigns: %{current_chatter: %{is_admin: false}}} = socket
      ) do
    {:noreply,
     ChatLive.prepend_to_active_room(
       socket,
       ChatLive.build_local_error("Unknown command: /unban")
     )}
  end

  def execute({:admin, :unban, ""}, socket) do
    {:noreply,
     ChatLive.prepend_to_active_room(
       socket,
       ChatLive.build_local_error("Usage: /unban <ip_or_username>")
     )}
  end

  def execute({:admin, :unban, target}, socket) do
    case Accounts.unban_user(target) do
      {:ok, count} ->
        {:noreply,
         ChatLive.prepend_to_active_room(
           socket,
           ChatLive.build_local_message(
             "System: Successfully removed #{count} ban record(s) for '#{target}'."
           )
         )}

      {:error, :not_found} ->
        {:noreply,
         ChatLive.prepend_to_active_room(
           socket,
           ChatLive.build_local_error("No active bans found matching '#{target}'.")
         )}
    end
  end

  # --------------------------------------------------------
  # LOCAL / SYSTEM COMMANDS
  # --------------------------------------------------------

  def execute({:local, :register, password}, socket) do
    username = socket.assigns.current_chatter.username

    case Accounts.register_chatter(%{username: username, password: password}) do
      {:ok, _chatter} ->
        {:noreply,
         ChatLive.prepend_to_active_room(
           socket,
           ChatLive.build_local_message("Success! The name #{username} is now registered.")
         )}

      {:error, changeset} ->
        {_field, {msg, _opts}} = Enum.at(changeset.errors, 0)

        {:noreply,
         ChatLive.prepend_to_active_room(
           socket,
           ChatLive.build_local_error("Registration failed: #{msg}")
         )}
    end
  end

  def execute({:local, :clear}, socket) do
    room = socket.assigns.active_room
    updated_map = Map.put(socket.assigns.messages_by_room, room, [])
    {:noreply, Phoenix.Component.assign(socket, messages_by_room: updated_map)}
  end

  # Catch Parser Errors
  def execute({:error, reason}, socket) do
    {:noreply, ChatLive.prepend_to_active_room(socket, ChatLive.build_local_error(reason))}
  end
end
