defmodule OneoffchatWeb.ChatComponents do
  @moduledoc """
  This module holds components related to the chat UI.
  """
  use Phoenix.Component
  import OneoffchatWeb.CoreComponents
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.ColocatedHook

  @doc """
  Renders the chat logo.
  """
  def logo(assigns) do
    ~H"""
    <div>
      <span class="font-brand select-none text-nord-7 [text-shadow:_2px_3px_1px_#111827] text-2xl md:text-3xl tracking-wide">
        OneOffChat
      </span>
    </div>
    """
  end

  @doc """
  Renders the chat preferences, including toggles for chatters and settings.
  """
  def preferences(assigns) do
    ~H"""
    <div class="flex -mt-2 items-center space-x-2">
      <div class="font-open-sans font-bold text-nord-15 [text-shadow:_1px_2px_2px_#111827] select-none">
        {@username}
      </div>
      <!-- toggle chatters -->
      <.toggle_chatters />
      <!-- toggle settings -->
      <.settings
        mute_notifications={@mute_notifications}
        ignore_dms={@ignore_dms}
      />
      <!-- toggle help -->
      <.help_menu username={@username} />
      <div>
        <button
          phx-click="leave_chat"
          class="tooltip tooltip-bottom p-0.5 bg-nord-11/20 rounded"
          data-tip="Exit"
        >
          <.icon name="hero-arrow-right-start-on-rectangle" class="w-6 h-6 text-nord-11" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders the toggle for chatters, which could be used to show/hide
  the list of chat participants.
  """
  def toggle_chatters(assigns) do
    ~H"""
    <div>
      <button
        type="button"
        class="outline-none"
        phx-click={
          JS.toggle_class("md:grid-cols-[1fr_14rem] md:grid-cols-[1fr_0px]", to: "#chat-layout-grid")
          |> JS.toggle_class("md:gap-2 md:gap-0", to: "#chat-layout-grid")
          |> JS.toggle_class("translate-x-full translate-x-0", to: "#chatters-panel-wrapper")
          |> JS.toggle_class("hidden block", to: "#mobile-backdrop")
        }
      >
        <.icon
          name="hero-user-group-micro"
          class="w-6 h-6 text-gray-400 hover:text-gray-300 transition-colors"
        />
      </button>
    </div>
    """
  end

  @doc """
  Renders the settings menu, which could include various chat preferences.
  """
  def settings(assigns) do
    ~H"""
    <div
      class="relative"
      role="toolbar"
      tabindex="0"
      phx-click-away={
        JS.hide(
          to: "#settings-panel",
          transition: {
            "transition ease-in duration-200 transform",
            "opacity-100 translate-y-0",
            "opacity-0 translate-y-[-10%]"
          },
          time: 200
        )
      }
    >
      <button
        type="button"
        class="outline-none"
        phx-click={
          JS.toggle(
            to: "#settings-panel",
            in:
              {"transition ease-out duration-200 transform", "opacity-0 translate-y-[-10%]",
               "opacity-100 translate-y-0"},
            out:
              {"transition ease-in duration-200 transform", "opacity-100 translate-y-0",
               "opacity-0 translate-y-[-10%]"},
            display: "block",
            time: 200
          )
        }
      >
        <.icon name="hero-cog-6-tooth" class="w-6 h-6 text-gray-400 hover:text-gray-300" />
      </button>
      <%!-- settings --%>
      <div
        id="settings-panel"
        class="hidden absolute space-y-4 mt-4 pb-4 -right-15 md:right-0 w-72 rounded-md bg-nord-1 shadow-md"
      >
        <div class="bg-nord-10/30 text-sm md:text-base shadow-md shadow-nord-1 rounded-t-md pl-4 py-1 text-gray-300 font-open-sans font-bold">
          Settings
        </div>
        <form phx-change="update_settings">
          <div class="flex mx-4 items-center justify-around space-x-5">
            <span class="flex-1 font-open-sans text-sm font-bold text-nord-6">
              Mute notifications
            </span>
            <.input
              type="checkbox"
              name="mute_notifications"
              class="toggle toggle-success"
              checked={@mute_notifications}
            />
          </div>
          <div class="flex mx-4 items-center justify-around space-x-5">
            <span class="flex-1 flex items-center space-x-2 font-open-sans text-sm font-bold text-nord-6">
              <span>Ignore DMs</span>
              <span
                class="tooltip tooltip-bottom"
                data-tip="If enabled, you won't receive any DMs. If you start a DM with someone, they will be able to message you.">
                <.icon name="hero-question-mark-circle" class="w-6 h-6 ml-1 text-nord-7" />
              </span>
            </span>
            <.input
              type="checkbox"
              name="ignore_dms"
              class="toggle toggle-success"
              checked={@ignore_dms}
            />
          </div>
        </form>
      </div>
    </div>
    """
  end

  def help_menu(assigns) do
    ~H"""
    <div
      class="relative"
      role="toolbar"
      tabindex="0"
      phx-click-away={
        JS.hide(
          to: "#help-menu-panel",
          transition: {
            "transition ease-in duration-200 transform",
            "opacity-100 translate-y-0",
            "opacity-0 translate-y-[-10%]"
          },
          time: 200
        )
      }
    >
      <button
        type="button"
        class="outline-none"
        phx-click={
          JS.toggle(
            to: "#help-menu-panel",
            in:
              {"transition ease-out duration-200 transform", "opacity-0 translate-y-[-10%]",
               "opacity-100 translate-y-0"},
            out:
              {"transition ease-in duration-200 transform", "opacity-100 translate-y-0",
               "opacity-0 translate-y-[-10%]"},
            display: "block",
            time: 200
          )
        }
      >
        <.icon name="hero-question-mark-circle-solid" class="w-6 h-6 text-gray-400 hover:text-gray-300" />
      </button>
      <%!-- help menu --%>
      <div
        id="help-menu-panel"
        class="hidden absolute -right-7 md:right-0 mt-4 w-72 rounded-md bg-nord-1 shadow-md"
      >
        <div class="bg-nord-10/30 text-sm md:text-base shadow-md shadow-nord-1 rounded-t-md pl-4 py-1 text-gray-300 font-open-sans font-bold">
          Available Commands
        </div>
        <div class="space-y-1 py-1 md:space-y-2 md:py-2">
          <.command_item
            command="/me"
            usage="/me says hello!"
            output={"* #{@username} says hello!"}
          />
          <.command_item
            command="/clear"
            usage="/clear"
            output="Clears chat history."
          />
          <.command_item
            command="/register"
            usage="/register <password>"
            output="Registers username with the specified password. You will be prompted for the password next time you join."
          />
        </div>
      </div>
    </div>
    """
  end

  def command_item(assigns) do
    ~H"""
    <div class="cmd-holder font-lato bg-gray-600 px-2 py-1 rounded mx-2">
      <div class="font-jb-mono font-bold text-nord-4">{@command}</div>
      <div>
        <div class="grid grid-cols-3 text-sm gap-1 bg-nord-1 px-1 py-0.5 rounded">
          <span class="col-span-1">Usage:</span>
          <span class="col-span-2">{@usage}</span>
        </div>
        <div class="grid grid-cols-3 text-sm gap-1 bg-nord-1 px-1 py-0.5 rounded mt-1">
          <span class="col-span-1">Output:</span>
          <span class={[
            "col-span-2",
            @command == "/me" && "text-orange-200 text-sm italic"
          ]}>
            {@output}
          </span>
        </div>
      </div>
    </div>
    """
  end

  def toggle_ignore(assigns) do
    ~H"""
    <div :if={@active_dm}>
      <%= if @active_dm in @ignored_chatters do %>
        <.button
          class="btn btn-soft btn-success btn-sm"
          phx-value-username={@active_dm}
          phx-click="unignore_chatter"
        >
          <.icon name="hero-check-circle" class="w-4 h-4 mr-1" /> Unignore {@active_dm}
        </.button>
      <% else %>
        <.button
          class="btn btn-soft btn-error btn-sm"
          phx-value-username={@active_dm}
          phx-click="ignore_chatter"
        >
          <.icon name="hero-no-symbol" class="w-4 h-4 mr-1" /> Ignore {@active_dm}
        </.button>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders the list of chatters currently in the chat room.
  """
  def chatter_list(assigns) do
    ~H"""
    <div
      id="chatters-panel"
      class="mr-1 h-full font-lato font-bold  bg-nord-9/10 mt-1 p-2 space-y-1 rounded-md shadow-inner shadow-nord-0 overflow-y-auto"
    >
      <h2 class="text-nord-7 border-b border-dashed border-nord-3 pl-1 pb-0.5">
        Chatters ({@chatters |> length()})
      </h2>
      <div
        :for={chatter <- @chatters}
        class="px-2 py-1 tracking-wide flex items-center space-x-2 rounded-md text-zinc-300 hover:bg-nord-3 hover:cursor-pointer"
        phx-click="open_dm"
        phx-value-username={chatter}
      >
        <.icon name="hero-user-solid" class="w-5 h-5" />
        <span>{chatter}</span>
      </div>
    </div>
    """
  end

  @doc """
  Renders the message input form, which allows users to type and send messages.
  """
  def message_input(assigns) do
    ~H"""
    <form
      id="message-form"
      class="z-40"
      phx-change="typing"
      phx-submit="send_message"
      phx-hook=".ChatComposer"
      data-room={@active_dm || @active_room}
    >
      <div class="flex">
        <textarea
          name="message"
          rows="1"
          class="font-gg-sans field-sizing-content resize-none flex-1 px-4 py-3 text-nord-6 rounded-l-md focus:outline-none bg-nord-2/30"
          placeholder={@active_dm in @ignored_chatters && "You ignored this user" || "Type a message..."}
          autocomplete="off"
          maxlength="300"
          phx-hook="MentionAutocomplete"
          id="chat-message-input"
          disabled={@active_dm in @ignored_chatters}
        ></textarea>
        <span class="right-0 flex items-center px-2 rounded-r-md bg-nord-2/30">
          <button
            type="submit"
            id="send-button"
            class="p-1 text-nord-8 disabled:text-nord-3 focus:outline-none focus:shadow-outline"
          >
            <.icon name="hero-paper-airplane" class="w-6 h-6" />
          </button>
        </span>
      </div>
    </form>
    <script :type={ColocatedHook} name=".ChatComposer">
      export default {
        mounted() {
          this.input = this.el.querySelector("textarea[name='message']");
          this.button = this.el.querySelector("#send-button");

          // Track the initial room
          this.currentRoom = this.el.dataset.room;

          this.input.focus();

          this.checkInput = () => {
            if (this.input.value.trim() === "" || this.input.disabled) {

              this.button.disabled = true;
            } else {
              this.button.disabled = false;
            }
          };

          this.checkInput();
          this.input.addEventListener("input", this.checkInput);

          this.input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              if (!this.button.disabled) {
                this.button.click();
              }
            }
          });

          this.el.addEventListener("submit", () => {
            if (this.input) {
              setTimeout(() => {
                this.input.value = "";
                this.checkInput();
              }, 10);
            }
          });
        },

        beforeUpdate() {
          this.draft = this.input.value;
        },

        updated() {
          // Check if the server changed the room
          if (this.el.dataset.room !== this.currentRoom) {
            // The room changed! Wipe the input and update our tracker.
            this.input.value = "";
            this.currentRoom = this.el.dataset.room;
          } else if (this.draft !== undefined) {
            // The room is the same (normal UI update), restore the draft.
            this.input.value = this.draft;
          }

          this.checkInput();
          this.input.focus();
        }
      }
    </script>
    """
  end

  @doc """
  Renders the "Jump to Present" button, which appears when the user scrolls up from the latest messages.
  """
  def jump_to_present(assigns) do
    ~H"""
    <div phx-update="ignore" class="absolute top-0 w-full" id="jtp-container">
      <button
        id="jump-to-present"
        phx-hook=".ScrollObserver"
        class="hidden w-full bg-nord-8 text-nord-0 px-4 py-1 rounded shadow-lg font-bold text-sm hover:bg-nord-9 transition z-50 cursor-pointer"
      >
        Jump to Present ↓
      </button>
    </div>
    <script :type={ColocatedHook} name=".ScrollObserver">
      export default {
        mounted() {
          this.anchor = document.getElementById("bottom-anchor");

          // Create the Intersection Observer
          this.observer = new IntersectionObserver((entries) => {
            let anchorEntry = entries[0];

            // If the anchor is NOT intersecting, we are scrolled up. Show the button!
            if (!anchorEntry.isIntersecting) {
              this.el.classList.remove("hidden");
            } else {
              // We are at the bottom. Hide it.
              this.el.classList.add("hidden");
            }
          }, {
            root: document.getElementById("chat-scroll-container"), // this.el.parentElement, // Observe relative to the scrolling container
            threshold: 0.1,
            rootMargin: "0px 0px 300px 0px"
          });

          this.observer.observe(this.anchor);

          // When the button is clicked, smoothly scroll the anchor into view
          this.el.addEventListener("click", () => {
            this.anchor.scrollIntoView({ behavior: "smooth", block: "end" });
          });
        },

        destroyed() {
          this.observer.disconnect();
        }
      }
    </script>
    """
  end



  @doc """
  Renders a channel button for switching between chat rooms.
  Displays the channel name, unread indicators, and mention counts.
  """
  attr :name, :string, required: true
  attr :current, :boolean, default: false
  attr :unread, :boolean, default: false
  attr :mentions, :integer, default: 0

  def channel(assigns) do
    ~H"""
    <button
      phx-click="switch_room"
      phx-value-room={@name}
      class={[
        "select-none flex space-x-2 items-center px-2 py-0.5 rounded border text-sm transition-colors duration-200",
        (@current && "bg-slate-800 text-nord-14/100") ||
          "bg-slate-700 hover:bg-slate-600 border-slate-600 text-nord-14/50",
        (@unread and not @current) && "text-nord-14/100"
      ]}
      disabled={@current}
    >
      <span>&num;{@name}</span>
      <span
        :if={@mentions > 0 and not @current}
        class="bg-nord-11 text-slate-100 text-xs font-bold rounded-sm size-4 text-center"
      >
        {@mentions}
      </span>
    </button>
    """
  end

  @doc """
  Renders a private message indicator for direct messages with a user.
  Shows the username and indicates if there are new messages.
  """
  attr :username, :string, required: true
  attr :current, :boolean, default: false
  attr :hasNewMessages, :boolean, default: false

  def private_message(assigns) do
    ~H"""
    <div class="flex">
      <button
        class={[
          "p-0.5 bg-nord-11 rounded-l border border-r-0 text-sm",
          (@current && "border-nord-11") || "border-slate-600",
        ]}
        phx-click="close_dm"
        phx-value-username={@username}
      >
        <.icon name="hero-x-mark" class="size-5 text-nord-1" />
      </button>
      <button
        class={[
          "select-none px-2 py-0.5 rounded-r border border-l-0 text-sm transition-colors duration-200",
          (@current && "text-nord-11/100 border-nord-11 bg-slate-800") || "bg-slate-700 hover:bg-slate-600 border-slate-600 text-nord-11/50",
          (@hasNewMessages and not @current) && "text-nord-11/100"
        ]}
        phx-click="open_dm"
        phx-value-username={@username}
        disabled={@current}
      >
        @{@username} {if(@hasNewMessages, do: "*")}
      </button>
    </div>
    """
  end

  @doc """
  Renders a divider indicating the beginning of the private chat history with a user.
  """
  def beginning_of_chat(assigns) do
    ~H"""
      <div class="flex items-center">
        <hr class="flex-grow border-t h-px border-gray-700" />
        <span class="px-3 text-gray-500 font-open-sans text-sm">
          This is the beginning of your chat with {@receiver}.
        </span>
        <hr class="flex-grow border-t border-gray-700" />
      </div>
    """
  end

  @doc """
  Renders a single chat message row, which can represent different types of messages
  (e.g., chat messages, join/leave notifications, emotes, errors).

  The styling and content of the row changes based on the message type.
  This component uses pattern matching to determine how to render each message type.
  """
  def message_row(%{message: %{type: :chat_msg}} = assigns) do
    ~H"""
    <div
      id={"msg-#{@message.id}"}
      class={["flex flex-col", @show_header && "mt-2", !@show_header && "mt-0.5"]}
    >
      <%!-- Only render the header if the functional check passed --%>
      <%= if @show_header do %>
        <div class="flex items-baseline space-x-2">
          <span class="font-lato text-nord-8">{@message.username}</span>
          <span
            id={"msg-date-#{@message.id}"}
            class="text-gray-400 text-[0.5em] self-center bg-bue-300 mt-1"
            phx-update="ignore"
          >
            <local-time datetime={DateTime.to_iso8601(@message.inserted_at)}></local-time>
          </span>
        </div>
      <% end %>
      <%!-- The message body --%>
      <div class={[
        "px-1 wrap-break-word leading-5 font-gg-sans text-gray-300 inline-block",
        mentioned_in_message?(@message, @current_username) && "bg-nord-13/20 rounded-xs py-0.5"
      ]}>
        <%= for chunk <- format_message_text(@message.text) do %><.message_body chunk={chunk} mentionables={@mentionables} /><% end %>
      </div>
    </div>
    """
  end

  def message_row(%{message: %{type: :join}} = assigns) do
    ~H"""
    <div id={"msg-#{@message.id}"} class="text-nord-14 text-xs font-bold font-open-sans">
      {@message.username} has joined the chat.
      <span
        id={"msg-date-#{@message.id}"}
        class="text-gray-400 text-[0.75em] self-center"
        phx-update="ignore"
      >
        <local-time datetime={DateTime.to_iso8601(@message.inserted_at)}></local-time>
      </span>
    </div>
    """
  end

  def message_row(%{message: %{type: :leave}} = assigns) do
    ~H"""
    <div id={"msg-#{@message.id}"} class="text-nord-11 text-xs font-bold font-open-sans">
      {@message.username} has left the chat.
      <span
        id={"msg-date-#{@message.id}"}
        class="text-gray-400 text-[0.75em] self-center"
        phx-update="ignore"
      >
        <local-time datetime={DateTime.to_iso8601(@message.inserted_at)}></local-time>
      </span>
    </div>
    """
  end

  def message_row(%{message: %{type: :system}} = assigns) do
    ~H"""
    <div
      id={"msg-#{@message.id}"}
      class="p-2 my-2 bg-nord-15/10 border border-dashed border-nord-7/30 rounded text-sm text-nord-7 font-jb-mono"
    >
      <span class="font-bold">
        [{@message.username}]
      </span>
      <span>{@message.text}</span>
      <%!-- <span class="text-gray-400 text-[0.75em] self-center">
        ({Calendar.strftime(@message.inserted_at, "%H:%M")})
      </span> --%>
    </div>
    """
  end

  def message_row(%{message: %{type: :emote}} = assigns) do
    ~H"""
    <div id={"msg-#{@message.id}"} class="text-orange-200 py-0.5 text-sm italic font-open-sans">
      * <span class="font-bold">{@message.username}</span> {@message.text}
      <span
        id={"msg-date-#{@message.id}"}
        class="text-gray-400 text-[0.75em] self-center not-italic"
        phx-update="ignore"
      >
        <local-time datetime={DateTime.to_iso8601(@message.inserted_at)}></local-time>
      </span>
    </div>
    """
  end

  def message_row(%{message: %{type: :welcome}} = assigns) do
    ~H"""
    <div
      id={"msg-#{@message.id}"}
      class="p-2 my-2 bg-nord-14/10 border border-dashed border-nord-7/30 rounded text-sm text-nord-14 font-jb-mono"
    >
      <span>
        Welcome to OneOffChat, a place with low moderation where you can anonymously chat.
        No crazy algorithms, no ads or tracking. Just a feel of good old internet. Just don't be a
        complete retard and you should be good. <br /><br />
        Please, be mindful that this is a public chat and avoid sharing any personal information.
      </span>
    </div>
    """
  end

  def message_row(%{message: %{type: :local_error}} = assigns) do
    ~H"""
    <div
      id={"#{@message.id}"}
      class="flex justify-between text-nord-13 text-xs bg-nord-11/10 rounded-xs border-dashed px-2 py-1 font-jb-mono my-1"
    >
      <span>{@message.text}</span>
      <button phx-click="dismiss_message" phx-value-id={@message.id}>
        <.icon name="hero-x-mark" class="text-red-300 size-4" />
      </button>
    </div>
    """
  end

  def message_row(%{message: %{type: :local_message}} = assigns) do
    ~H"""
    <div
      id={"#{@message.id}"}
      class="text-nord-14 text-xs bg-nord-8/30 rounded-xs border-dashed px-2 py-1 font-jb-mono my-1"
    >
      <span>{@message.text}</span>
    </div>
    """
  end

  def message_row(%{message: %{type: :kick}} = assigns) do
    ~H"""
    <div id={"msg-#{@message.id}"} class="text-xs font-bold font-jb-mono">
      <span class="text-nord-8">&laquo;{@message.username}&raquo;</span>
      <span class="text-nord-6">{@message.text}</span>
      <span
        id={"msg-date-#{@message.id}"}
        class="text-gray-400 text-[0.75em] self-center"
        phx-update="ignore"
      >
        <local-time datetime={DateTime.to_iso8601(@message.inserted_at)}></local-time>
      </span>
    </div>
    """
  end

  def message_row(%{message: %{type: :ban}} = assigns) do
    ~H"""
    <div id={"msg-#{@message.id}"} class="text-xs font-bold font-jb-mono">
      <span class="text-nord-8">&laquo;{@message.username}&raquo;</span>
      <span class="text-nord-6">{@message.text}</span>
      <span
        id={"msg-date-#{@message.id}"}
        class="text-gray-400 text-[0.75em] self-center"
        phx-update="ignore"
      >
        <local-time datetime={DateTime.to_iso8601(@message.inserted_at)}></local-time>
      </span>
    </div>
    """
  end

  @doc """
  Determines if a message should display the username/avatar header.
  """
  # Rule 1: Compare two normal chat messages
  def show_header?(%{type: :chat_msg} = current_msg, %{type: :chat_msg} = previous_msg) do
    same_user? = current_msg.username == previous_msg.username

    # Format both down to the minute to easily check if they share the same time window
    same_minute? =
      Calendar.strftime(current_msg.inserted_at, "%Y-%m-%d %H:%M") ==
        Calendar.strftime(previous_msg.inserted_at, "%Y-%m-%d %H:%M")

    # If they are NOT the same user in the SAME minute, show the header
    not (same_user? and same_minute?)
  end

  # Rule 2: If the previous message was a system alert/emote, the new chat message NEEDS a header
  def show_header?(%{type: :chat_msg}, _previous_msg), do: true

  # Rule 3: System messages and emotes handle their own UI, so default to true
  def show_header?(_current_msg, _previous_msg), do: true

  # Helper to split a message into normal text and mentions
  defp format_message_text(text) do
    # The regex looks for an @ symbol followed by word characters.
    # The (?<=^|\s) is a "lookbehind" that ensures it only matches if the @
    # is at the beginning of the message or immediately follows a space.
    # This prevents it from accidentally highlighting emails like "user@domain.com".

    # This Regex uses the OR operator (|) inside a single capture group.
    # It looks for a mention OR a YouTube link.
    regex = ~r/((?<=^|\s)@[a-zA-Z0-9_]+|https?:\/\/(?:www\.)?(?:youtube\.com|youtu\.be)\/[^\s]+)/

    # include_captures: true is the magic that keeps the "@username" in the list!
    Regex.split(regex, text, include_captures: true)
  end

  # Helper to identify if a string is a YouTube link
  defp youtube_link?(chunk) do
    # Note the ^ and $ at the ends to ensure the WHOLE chunk is the link
    Regex.match?(~r/^https?:\/\/(?:www\.)?(?:youtube\.com|youtu\.be)\/[^\s]+$/, chunk)
  end

  defp mentioned_in_message?(message, current_username) do
    if Map.get(message, :is_historical, false) do
      false
    else
      # Don't highlight if they mentioned themselves
      if message.username == current_username do
        false
      else
        # \b ensures we match "@John" but NOT "@JohnDoe"
        # Regex.escape protects against usernames with special characters
        Regex.match?(~r/@#{Regex.escape(current_username)}\b/, message.text)
      end
    end
  end

  defp valid_mention?(chunk, online_usernames) do
    if String.starts_with?(chunk, "@") do
      username = String.trim_leading(chunk, "@")

      username in online_usernames
    else
      false
    end
  end

  defp message_body(assigns) do
    cond do
      # 1. Is it a valid mention?
      valid_mention?(assigns.chunk, assigns.mentionables) ->
        ~H(<span class="underline underline-offset-3 decoration-nord-12 text-nord-13 font-bold">{@chunk}</span>)

      # 2. Is it a YouTube link?
      youtube_link?(assigns.chunk) ->
        ~H"""
        <a
          href={@chunk}
          target="_blank"
          rel="noopener noreferrer"
          class="text-nord-8 hover:text-nord-7 underline underline-offset-2 decoration-nord-8/50 font-semibold transition-colors"
        ><.icon name="hero-play-circle-solid" class="w-4 h-4 -mt-1 mr-0.5" />YouTube</a>
        """

      # 3. If it's neither, just render plain text safely!
      true ->
        ~H({@chunk})
    end
  end

  @doc """
  Renders the typing indicator based on the list of users currently typing.
  """
  def format_typing(%{typing_chatters: []} = assigns) do
    ~H""
  end

  # Exactly one person is typing
  def format_typing(%{typing_chatters: [chatter]} = assigns) do
    # We assign the local variable so we can use it in the HEEx
    assigns = assign(assigns, :chatter, chatter)

    ~H"""
    <span class="font-bold">{@chatter}</span> is typing...
    """
  end

  # Exactly two people are typing
  def format_typing(%{typing_chatters: [chatter1, chatter2]} = assigns) do
    assigns =
      assigns
      |> assign(:chatter1, chatter1)
      |> assign(:chatter2, chatter2)

    ~H"""
    <span class="font-bold">{@chatter1}</span>
    and <span class="font-bold">{@chatter2}</span>
    are typing...
    """
  end

  # Three or more people are typing
  def format_typing(%{typing_chatters: [_ | _]} = assigns) do
    ~H"""
    Several people are typing...
    """
  end
end
