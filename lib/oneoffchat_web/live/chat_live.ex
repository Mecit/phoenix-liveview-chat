defmodule OneoffchatWeb.ChatLive do
  @moduledoc """
  The main LiveView module for the chat interface. This is where we handle all real-time interactions,
  including message sending, presence updates, and command parsing.
  """
  use OneoffchatWeb, :live_view

  alias OneoffchatWeb.Presence
  alias Oneoffchat.Chat
  alias Oneoffchat.Accounts
  alias Oneoffchat.Chat.MessageParser
  alias Oneoffchat.Accounts.Chatter
  alias OneoffchatWeb.ChatLive.CommandHandler
  alias Oneoffchat.Chat.RateLimiter
  alias Oneoffchat.Chat.RoomState
  alias OneoffchatWeb.ChatBouncer

  @available_rooms ["general", "chill", "dev"]

  def mount(_params, session, socket) do
    # 1. Grab the X-Headers list (returns nil if not configured, so we default to [])
    headers = get_connect_info(socket, :x_headers) || []

    # 2. Extract the real IP, falling back to peer_data for local localhost testing
    ip_address =
      case List.keyfind(headers, "x-forwarded-for", 0) do
        {"x-forwarded-for", forwarded_ips} ->
          # Grab the first IP in case of a comma-separated list
          forwarded_ips
          |> String.split(",")
          |> List.first()
          |> String.trim()

        nil ->
          # Localhost fallback
          ip_tuple = get_connect_info(socket, :peer_data).address
          ip_tuple |> :inet_parse.ntoa() |> to_string()
      end
      |> Accounts.normalize_ip()

    changeset = Chatter.changeset(%Chatter{}, %{})

    device_id = Map.get(session, "device_id")

    initial_unreads =
      Map.new(@available_rooms, fn room ->
        {room, %{unread: false, mentions: 0}}
      end)

    socket =
      assign(socket,
        # --- Connection & Authentication ---
        ip_address: ip_address,
        device_id: device_id,
        current_chatter: nil,
        form: to_form(changeset),
        require_password: false,

        # --- Global chat state ---
        active_room: "general",
        joined_rooms: @available_rooms,
        messages_by_room: %{},
        online_chatters: [],
        typing_chatters: [],
        typing_timer: nil,

        # --- Private messaging (DMs) state ---
        active_dm: nil,
        open_dms: [],
        private_messages: %{},
        unread_dms: [],
        dm_typing_status: %{},

        # --- User preferences & UI ---
        mute_notifications: false,
        ignore_dms: false,
        ignored_chatters: [],
        unread_status: initial_unreads,

        # --- Security & Rate Limiting ---
        message_timestamps: [],
        cooldown_until: nil
      )

    {:ok, socket}
  end

  def handle_event("validate_username", %{"chatter" => chatter}, socket) do
    changeset = Chatter.changeset(%Chatter{}, chatter)
    username = chatter["username"]

    is_registered? = Accounts.chatter_registered?(username)

    changeset =
      if ChatBouncer.username_active?(username) do
        Ecto.Changeset.add_error(changeset, :username, "This username is already taken.")
      else
        changeset
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset), require_password: is_registered?)}
  end

  def handle_event("join_chat", %{"chatter" => chatter_params}, socket) do
    # Run the exact same format validation used in phx-change
    changeset = Chatter.changeset(%Chatter{}, chatter_params)

    if changeset.valid? do
      # Format is good. Let the Bouncer do the heavy lifting.
      client_ip = socket.assigns.ip_address
      device_id = socket.assigns.device_id

      case ChatBouncer.check_entry(chatter_params, client_ip, device_id) do
        {:error, field, message} ->
          # Rebuild the changeset and inject the specific error from the bouncer
          changeset =
            Chatter.changeset(%Chatter{}, chatter_params)
            |> Ecto.Changeset.add_error(field, message)
            |> Map.put(:action, :validate)

          {:noreply, assign(socket, form: to_form(changeset))}

        {:ok, current_chatter} ->
          # Fetch History
          messages_by_room =
            Enum.into(@available_rooms, %{}, fn room ->
              msgs = Chat.list_recent_messages(room) |> Enum.map(&%{&1 | is_historical: true})
              {room, msgs}
            end)

          # Start the Real-time Engine
          if connected?(socket) do
            Phoenix.PubSub.subscribe(Oneoffchat.PubSub, "chat:global")

            # Subscribe to a personal frequency for Private Messages
            Phoenix.PubSub.subscribe(Oneoffchat.PubSub, "private:#{current_chatter.username}")

            # Subscribe to global system events
            Phoenix.PubSub.subscribe(Oneoffchat.PubSub, "system:presence")

            Enum.each(socket.assigns.joined_rooms, fn room ->
              Phoenix.PubSub.subscribe(Oneoffchat.PubSub, "chat:#{room}")
            end)

            send(self(), :after_join)
          end

          socket =
            socket
            |> assign(current_chatter: current_chatter)
            |> assign(messages_by_room: messages_by_room)
            |> clear_flash()

          {:noreply, socket}
      end
    else
      # 3. They typed too fast and hit enter with invalid data.
      # Block the login and show the red validation errors.
      {:noreply, assign(socket, form: to_form(changeset |> Map.put(:action, :validate)))}
    end
  end

  # Opening a DM
  def handle_event("open_dm", %{"username" => target_user}, socket) do
    # Check our two valid conditions
    is_online? = ChatBouncer.username_active?(target_user)
    has_history? = Map.has_key?(socket.assigns.private_messages, target_user)

    cond do
      # Prevent self-DMs
      target_user == socket.assigns.current_chatter.username ->
        {:noreply, socket}

      # Prevent fake users, BUT allow re-opening existing DMs.
      not is_online? and not has_history? ->
        socket = put_flash(socket, :error, "That user is not currently online.")
        {:noreply, socket}

      # The Happy Path
      true ->
        # Force-clear their typing status in the background room
        Presence.update(
          self(),
          "chat:#{socket.assigns.active_room}",
          socket.assigns.current_chatter.username,
          build_presence_meta(socket)
        )

        open_dms =
          if target_user in socket.assigns.open_dms do
            socket.assigns.open_dms
          else
            [target_user | socket.assigns.open_dms]
          end

        private_messages = Map.put_new(socket.assigns.private_messages, target_user, [])

        # Clear the unread status for this user
        unread_dms = List.delete(socket.assigns.unread_dms, target_user)

        socket =
          socket
          |> assign(open_dms: open_dms)
          |> assign(private_messages: private_messages)
          |> assign(active_dm: target_user)
          |> assign(unread_dms: unread_dms)

        {:noreply, socket}
    end
  end

  # Closing a DM tab
  def handle_event("close_dm", %{"username" => target_user}, socket) do
    # Remove from the visible list
    open_dms = List.delete(socket.assigns.open_dms, target_user)

    # If we were looking at the DM we just closed, fall back to the active room
    active_dm =
      if socket.assigns.active_dm == target_user, do: nil, else: socket.assigns.active_dm

    socket =
      socket
      |> assign(open_dms: open_dms)
      |> assign(active_dm: active_dm)

    {:noreply, socket}
  end

  def handle_event("ignore_chatter", %{"username" => bad_user}, socket) do
    # 1. Add the user to the ignore list (ensuring no duplicates)
    new_list = Enum.uniq([bad_user | socket.assigns.ignored_chatters])
    socket = assign(socket, ignored_chatters: new_list)

    # 2. Update the Global Billboard so everyone's Bouncer knows!
    Presence.update(
      self(),
      "users:global",
      socket.assigns.current_chatter.username,
      build_presence_meta(socket)
    )

    {:noreply, socket}
  end

  def handle_event("unignore_chatter", %{"username" => forgiven_user}, socket) do
    # Remove the user from the ignore list
    new_list = List.delete(socket.assigns.ignored_chatters, forgiven_user)
    socket = assign(socket, ignored_chatters: new_list)

    # Update the Global Billboard so ignored user's Bouncer knows they are unblocked!
    Presence.update(
      self(),
      "users:global",
      socket.assigns.current_chatter.username,
      build_presence_meta(socket)
    )

    {:noreply, socket}
  end

  def handle_event("typing", _params, socket) do
    if is_nil(socket.assigns.active_dm) do
      # Cancel the existing cooldown timer if they are still typing
      if timer = socket.assigns.typing_timer do
        Process.cancel_timer(timer)
      end

      # Start a new 2-second countdown FIRST
      # We pass the timer reference into the message.
      new_timer = Process.send_after(self(), :clear_typing, 2000)

      # Update the socket state BEFORE calling Presence
      # This is crucial so build_presence_meta(socket) sees that a timer exists.
      socket = assign(socket, typing_timer: new_timer)

      # Update their Presence metadata
      Presence.update(
        self(),
        "chat:#{socket.assigns.active_room}",
        socket.assigns.current_chatter.username,
        build_presence_meta(socket)
      )

      {:noreply, socket}
    else
      # --- PRIVATE MESSAGE MODE ---
      target_user = socket.assigns.active_dm

      # Only broadcast the typing event if they are actually allowed to send a message!
      if target_user not in socket.assigns.ignored_chatters and
           can_message_target?(target_user, socket) do
        sender = socket.assigns.current_chatter.username

        Phoenix.PubSub.broadcast(
          Oneoffchat.PubSub,
          "private:#{target_user}",
          {:dm_typing, sender}
        )
      end

      {:noreply, socket}
    end
  end

  # Catch the event sent by the JS Hook
  def handle_event("search_mentions", %{"query" => query}, socket) do
    # Normalize the query for a case-insensitive search
    search_term = String.downcase(query)

    # Filter the currently online chatters
    matches =
      socket.assigns.online_chatters
      |> Enum.filter(fn username ->
        String.starts_with?(String.downcase(username), search_term)
      end)
      # Only return the top 5 matches!
      |> Enum.take(5)

    # Notice we use :reply instead of :noreply!
    # This sends the data directly back to the JS callback without updating assigns or the DOM.
    {:reply, %{matches: matches}, socket}
  end

  @doc """
  This is the main message handler for incoming chat messages.
  It implements a simple anti-spam mechanism that checks how many messages the user has sent
  in the last 15 seconds. If they exceed the limit, they are put in a temporary penalty box
  and receive a local error message.

  Otherwise, their message is processed and broadcasted to the room.
  """
  def handle_event("send_message", %{"message" => raw_text}, socket)
      when not is_nil(socket.assigns.current_chatter.username) do
    # Extract the timer, and immediately clear it from the socket state.
    timer = socket.assigns.typing_timer
    socket = assign(socket, typing_timer: nil)

    if timer do
      Process.cancel_timer(timer)

      if is_nil(socket.assigns.active_dm) do
        Presence.update(
          self(),
          "chat:#{socket.assigns.active_room}",
          socket.assigns.current_chatter.username,
          build_presence_meta(socket)
        )
      end
    end

    # Check rate limiter
    case RateLimiter.check_rate(socket.assigns.message_timestamps, socket.assigns.cooldown_until) do
      {:error, :in_cooldown, remaining, _timestamps} ->
        msg = build_local_error("Please, wait #{remaining} seconds.")
        {:noreply, prepend_to_active_view(socket, msg)}

      {:error, :rate_limited, cooldown, _timestamps} ->
        msg = build_local_error("You're sending messages too fast. Wait #{cooldown} seconds.")

        socket =
          socket
          |> assign(cooldown_until: System.system_time(:second) + cooldown)
          |> assign(message_timestamps: [])
          |> prepend_to_active_view(msg)

        {:noreply, socket}

      {:ok, new_timestamps} ->
        socket = assign(socket, message_timestamps: new_timestamps)

        # ROUTE THE MESSAGE
        if socket.assigns.active_dm do
          # --- PRIVATE MESSAGE MODE ---
          target_user = socket.assigns.active_dm

          # SANITIZE: Trim whitespace from the raw text.
          clean_text = String.trim(raw_text)

          cond do
            # Guard 1: Did they bypass the JS button and send an empty string?
            clean_text == "" ->
              {:noreply, socket}

            # Guard 2: The Server-Side Length Check.
            String.length(clean_text) > 300 ->
              msg = build_local_error("Messages can't be longer than 300 characters.")
              {:noreply, prepend_to_active_view(socket, msg)}

            # THE NEW GUARD: Did Alice ignore this user?
            target_user in socket.assigns.ignored_chatters ->
              msg =
                build_local_error(
                  "You cannot message a user you have ignored. Unignore them first."
                )

              {:noreply, prepend_to_active_view(socket, msg)}

            # The Happy Path: Proceed with permissions check.
            can_message_target?(target_user, socket) ->
              # They accept DMs or they messaged us first.
              attrs = %{
                text: raw_text,
                type: :chat_msg,
                username: socket.assigns.current_chatter.username,
                receiver: target_user
              }

              case Chat.create_private_message(attrs) do
                {:ok, saved_pm} ->
                  Phoenix.PubSub.broadcast(
                    Oneoffchat.PubSub,
                    "private:#{target_user}",
                    {:new_dm, saved_pm}
                  )

                  history = Map.get(socket.assigns.private_messages, target_user, [])

                  private_messages =
                    Map.put(socket.assigns.private_messages, target_user, [saved_pm | history])

                  {:noreply, assign(socket, private_messages: private_messages)}

                {:error, _changeset} ->
                  {:noreply, socket}
              end

            true ->
              # They blocked dms and did not initiate
              msg = build_local_error("This user doesn't accept DMs.")
              {:noreply, prepend_to_active_view(socket, msg)}
          end
        else
          # --- NORMAL ROOM MODE ---
          instruction =
            MessageParser.parse(String.trim(raw_text), socket.assigns.current_chatter.username)

          {:noreply, updated_socket} = CommandHandler.execute(instruction, socket)

          {:noreply, updated_socket}
        end
    end
  end

  # The fallback guard
  # If the form submits without a "message" key (e.g., the input was disabled),
  # we silently catch it and do nothing instead of crashing the LiveView.
  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("switch_room", %{"room" => new_room}, socket) do
    if new_room == socket.assigns.active_room and is_nil(socket.assigns.active_dm) do
      {:noreply, socket}
    else
      # Reset the unread and mention tracking for the room they just entered.
      updated_unreads = RoomState.clear_room(socket.assigns.unread_status, new_room)

      # Recalculate the global total (in case other rooms still have mentions).
      total_mentions = RoomState.total_mentions(updated_unreads)

      # No database query needed. Just swap the active room and refresh presence.
      socket =
        socket
        |> assign(active_room: new_room)
        |> assign(typing_chatters: [])
        |> assign(unread_status: updated_unreads)
        |> assign(active_dm: nil)
        |> assign(
          page_title:
            if(total_mentions > 0, do: "(#{total_mentions}) OneoffChat", else: "OneoffChat")
        )
        |> sync_presence()

      {:noreply, socket}
    end
  end

  def handle_event("leave_chat", _params, socket) do
    {:noreply, push_navigate(socket, to: "/")}
  end

  def handle_event("update_settings", params, socket) do
    # Parse the values from the form (adjust the keys to match your HTML inputs).
    mute_notifications? = params["mute_notifications"] == "true"
    ignore_dms? = params["ignore_dms"] == "true"

    # Update the local socket.
    socket =
      socket
      |> assign(mute_notifications: mute_notifications?)
      |> assign(ignore_dms: ignore_dms?)

    # Broadcast the new DM preference to the public room.
    # We use 'not ignore_dms?' so the public flag is a positive 'accepts_dms: true'.
    Presence.update(
      self(),
      "users:global",
      socket.assigns.current_chatter.username,
      build_presence_meta(socket)
    )

    {:noreply, socket}
  end

  def handle_event("dismiss_message", %{"id" => message_id}, socket) do
    if target_user = socket.assigns.active_dm do
      # --- PRIVATE MESSAGE MODE ---
      # Grab the current list of messages for the active DM
      current_messages = Map.get(socket.assigns.private_messages, target_user, [])

      # Filter out the message
      updated_messages =
        Enum.reject(current_messages, fn msg ->
          to_string(msg.id) == to_string(message_id)
        end)

      # Update the private map and assign
      updated_map = Map.put(socket.assigns.private_messages, target_user, updated_messages)
      {:noreply, assign(socket, private_messages: updated_map)}
    else
      # --- NORMAL ROOM MODE ---
      room = socket.assigns.active_room

      # Grab the current list of messages for the active room
      current_messages = Map.get(socket.assigns.messages_by_room, room, [])

      # Filter out the message
      updated_messages =
        Enum.reject(current_messages, fn msg ->
          to_string(msg.id) == to_string(message_id)
        end)

      # Update the public map and assign
      updated_map = Map.put(socket.assigns.messages_by_room, room, updated_messages)
      {:noreply, assign(socket, messages_by_room: updated_map)}
    end
  end

  def build_local_error(text) do
    %{
      id: "error-#{System.unique_integer([:positive])}",
      type: :local_error,
      text: text
    }
  end

  def build_local_message(text) do
    %{
      id: "info-#{System.unique_integer([:positive])}",
      type: :local_message,
      text: text
    }
  end

  # Helper to prepend a message ONLY to the room the user is currently looking at
  def prepend_to_active_room(socket, message) do
    room = socket.assigns.active_room
    current_msgs = Map.get(socket.assigns.messages_by_room, room, [])

    updated_map = Map.put(socket.assigns.messages_by_room, room, [message | current_msgs])

    assign(socket, messages_by_room: updated_map)
  end

  defp prepend_to_active_view(socket, msg) do
    if target_user = socket.assigns.active_dm do
      # We are in a DM, route it to the private messages map
      history = Map.get(socket.assigns.private_messages, target_user, [])
      private_messages = Map.put(socket.assigns.private_messages, target_user, [msg | history])

      assign(socket, private_messages: private_messages)
    else
      # We are in a room, route it to the public messages map
      active_room = socket.assigns.active_room
      history = Map.get(socket.assigns.messages_by_room, active_room, [])
      messages_by_room = Map.put(socket.assigns.messages_by_room, active_room, [msg | history])

      assign(socket, messages_by_room: messages_by_room)
    end
  end

  def handle_info(:after_join, socket) do
    username = socket.assigns.current_chatter.username

    {:ok, _} =
      Presence.track(self(), "chat:global", username, %{
        device_id: socket.assigns.device_id,
        ip_address: socket.assigns.ip_address
        # We don't need 'typing' or 'joined_at' here since global is just for network data
      })

    # Track the user in EVERY room they joined
    Enum.each(socket.assigns.joined_rooms, fn room ->
      {:ok, _} =
        Presence.track(self(), "chat:#{room}", username, %{
          joined_at: :os.system_time(:seconds),
          typing: false,
          device_id: socket.assigns.device_id,
          ip_address: socket.assigns.ip_address
        })
    end)

    # Track them in the global topic simultaneously.
    Presence.track(
      self(),
      "users:global",
      username,
      build_presence_meta(socket)
    )

    {:noreply, sync_presence(socket)}
  end

  # Catch the built-in presence updates
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: _diff}, socket) do
    # When someone joins or leaves, simply re-fetch the list
    {:noreply, sync_presence(socket)}
  end

  # Catch incoming DMs
  def handle_info({:new_dm, message}, socket) do
    sender = message.username
    # Update the local message history
    history = Map.get(socket.assigns.private_messages, sender, [])
    private_messages = Map.put(socket.assigns.private_messages, sender, [message | history])

    # Instantly clear their typing status
    new_typing_status = Map.delete(socket.assigns.dm_typing_status, sender)

    # Ensure their name pops up in our Open DMs list
    # Ensure the sender has a tab rendered in the UI.
    open_dms =
      if sender in socket.assigns.open_dms do
        socket.assigns.open_dms
      else
        [sender | socket.assigns.open_dms]
      end

    socket =
      socket
      |> assign(open_dms: open_dms)
      |> assign(private_messages: private_messages)
      |> assign(dm_typing_status: new_typing_status)

    # Handle the Unread Badge & Sound
    is_active_dm? = socket.assigns.active_dm == sender

    socket =
      if not is_active_dm? do
        # Prepend to the unread list, ensuring no duplicates
        unread_dms = Enum.uniq([sender | socket.assigns.unread_dms])

        socket = assign(socket, unread_dms: unread_dms)

        # Play the notification ping if they haven't muted sounds
        if not socket.assigns.mute_notifications do
          push_event(socket, "play_background_ping", %{})
        else
          socket
        end
      else
        socket
      end

    {:noreply, socket}
  end

  # We pattern match the exact timer reference out of the socket
  def handle_info(:clear_typing, %{assigns: %{typing_timer: timer}} = socket)
      when not is_nil(timer) do
    # Clear the timer from the state
    socket = assign(socket, typing_timer: nil)

    # Update presence with the new state (build_presence_meta will see nil and return false)
    Presence.update(
      self(),
      "chat:#{socket.assigns.active_room}",
      socket.assigns.current_chatter.username,
      build_presence_meta(socket)
    )

    {:noreply, socket}
  end

  # If a rogue :clear_typing message arrives but the timer is already nil (or changed),
  # we just safely ignore it.
  def handle_info(:clear_typing, socket), do: {:noreply, socket}

  # Catch the typing broadcast
  def handle_info({:dm_typing, sender}, socket) do
    typing_status = socket.assigns.dm_typing_status

    # Cancel the existing timer if they are still actively typing
    if existing_timer = Map.get(typing_status, sender) do
      Process.cancel_timer(existing_timer)
    end

    # Start a fresh 2-second countdown
    timer_ref = Process.send_after(self(), {:clear_dm_typing, sender}, 2000)

    # Store the new timer in the map
    new_status = Map.put(typing_status, sender, timer_ref)

    {:noreply, assign(socket, dm_typing_status: new_status)}
  end

  # Catch the timeout to clear the typing status
  def handle_info({:clear_dm_typing, sender}, socket) do
    new_status = Map.delete(socket.assigns.dm_typing_status, sender)
    {:noreply, assign(socket, dm_typing_status: new_status)}
  end

  def handle_info({:new_message, message}, socket) do
    # Safely determine if the user is actively looking at this room's chat window
    is_viewing_room? =
      message.room == socket.assigns.active_room and is_nil(socket.assigns.active_dm)

    # Update the in-memory cache for whatever room this message belongs to
    current_room_messages = Map.get(socket.assigns.messages_by_room, message.room, [])
    updated_room_messages = [message | current_room_messages]

    socket =
      assign(
        socket,
        messages_by_room:
          Map.put(socket.assigns.messages_by_room, message.room, updated_room_messages)
      )

    # Check for Welcome message logic (if it's YOUR join message)
    socket =
      if message.room == socket.assigns.active_room and
           message.type == :join and
           message.username == socket.assigns.current_chatter.username do
        welcome_msg = %{
          id: "welcome-#{System.unique_integer([:positive])}",
          type: :welcome,
          room: socket.assigns.active_room
        }

        # We prepend the welcome message to the list we JUST updated,
        # and then safely put that new list back into the Map.
        final_room_messages = [welcome_msg | updated_room_messages]

        assign(socket,
          messages_by_room:
            Map.put(socket.assigns.messages_by_room, message.room, final_room_messages)
        )
      else
        socket
      end

    is_mention? =
      is_binary(message.text) and
        message.username != socket.assigns.current_chatter.username and
        Regex.match?(
          ~r/@#{Regex.escape(socket.assigns.current_chatter.username)}\b/,
          message.text
        )

    # Play the sound if it's a mention
    socket =
      if is_mention? and not socket.assigns.mute_notifications do
        push_event(socket, "play_background_ping", %{})
      else
        socket
      end

    # Handle Background Mentions & Unread Badges.
    socket =
      if not is_viewing_room? do
        # Calculate the new state
        updated_unreads =
          RoomState.add_mention(socket.assigns.unread_status, message.room, is_mention?)

        total_mentions = RoomState.total_mentions(updated_unreads)

        socket
        |> assign(unread_status: updated_unreads)
        |> assign(
          page_title:
            if(total_mentions > 0, do: "(#{total_mentions}) OneOffChat", else: "OneOffChat")
        )
      else
        socket
      end

    {:noreply, socket}
  end

  # Catch the global disconnect event
  def handle_info({:user_left, leaving_username}, socket) do
    socket =
      if leaving_username in socket.assigns.open_dms do
        history = Map.get(socket.assigns.private_messages, leaving_username, [])

        # Match exactly on the :leave type and the pinned username
        already_notified? =
          case history do
            [%{type: :leave, username: ^leaving_username} | _] -> true
            _ -> false
          end

        if already_notified? do
          socket
        else
          # Create the structured :leave message
          leave_message = %{
            id: "#{System.unique_integer([:positive])}",
            type: :leave,
            username: leaving_username,
            inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
            is_historical: false
          }

          # Inject it specifically into their DM history
          updated_pms =
            Map.put(socket.assigns.private_messages, leaving_username, [leave_message | history])

          # Instantly clear their typing status
          updated_typing = Map.delete(socket.assigns.dm_typing_status, leaving_username)

          socket
          |> assign(private_messages: updated_pms)
          |> assign(dm_typing_status: updated_typing)
        end
      else
        socket
      end

    {:noreply, socket}
  end

  # Update your existing catch to include the reason
  def handle_info({:kick_user, target_user, reason}, socket) do
    if socket.assigns.current_chatter.username == target_user do
      # It's us. Show the reason and kick them out.
      socket =
        socket
        |> put_flash(:error, "You have been kicked. Reason: #{reason}")
        |> redirect(to: "/")

      {:noreply, socket}
    else
      # Not us. Ignore it.
      {:noreply, socket}
    end
  end

  # Helper function to parse Presence data
  defp sync_presence(socket) do
    presence_data = Presence.list("chat:#{socket.assigns.active_room}")

    # Get all online usernames
    online_chatters = Map.keys(presence_data)

    # Filter out anyone who has `typing: true` (except the current user)
    typing_chatters =
      presence_data
      |> Enum.filter(fn {username, data} ->
        # data.metas is a list of all their open tabs/connections
        is_typing? = Enum.any?(data.metas, fn meta -> meta.typing == true end)
        is_typing? and username != socket.assigns.current_chatter.username
      end)
      |> Enum.map(fn {username, _data} -> username end)

    socket
    |> assign(online_chatters: online_chatters)
    |> assign(typing_chatters: typing_chatters)
  end

  defp build_presence_meta(socket) do
    %{
      typing: not is_nil(socket.assigns.typing_timer),
      device_id: socket.assigns.device_id,
      accepts_dms: not socket.assigns.ignore_dms,
      ignored_chatters: socket.assigns.ignored_chatters
    }
  end

  # This function checks if we are allowed to send a DM to the target user based on two conditions:
  # 1. The global presence state of the target user (do they accept DMs?)
  # 2. The local chat history with that user (have they messaged us before?)
  defp can_message_target?(target_user, socket) do
    sender = socket.assigns.current_chatter.username
    # 1. THE ABSOLUTE GUARD: Did they explicitly block us?
    if ChatBouncer.has_blocked?(target_user, sender) do
      false
    else
      # Check global presence state
      accepts_dms = ChatBouncer.accepts_dms?(target_user)

      # Check local history to see if they initiated contact
      history = Map.get(socket.assigns.private_messages, target_user, [])

      # Safely fetch the username key, defaulting to nil if it's a system message
      target_messaged_first =
        Enum.any?(history, fn msg ->
          Map.get(msg, :username) == target_user
        end)

      # Allow if either is true.
      accepts_dms or target_messaged_first
    end
  end

  @doc """
  This function serves as the single source of truth for broadcasting new messages to a room.
  """
  def broadcast_message(attrs) do
    case Chat.create_message(attrs) do
      {:ok, saved_message} ->
        # Inject the ID for the DOM, then broadcast
        Phoenix.PubSub.broadcast(
          Oneoffchat.PubSub,
          "chat:#{saved_message.room}",
          {:new_message, saved_message}
        )

        {:ok, saved_message}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
