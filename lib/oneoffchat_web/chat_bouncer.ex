defmodule OneoffchatWeb.ChatBouncer do
  @moduledoc """
  The ChatBouncer module is responsible for enforcing all the rules and checks that determine whether a user can enter the chat. This includes:
  - Checking if the username or IP address is banned.
  - Ensuring the user doesn't have an active session in another tab.
  - Verifying that the username isn't already taken in any of the chat rooms.
  - Validating the password for registered users.
  """
  alias Oneoffchat.Accounts
  alias OneoffchatWeb.Presence

  @available_rooms ["general", "chill", "dev"]

  @doc """
  Runs the full suite of authorization checks for a user trying to enter the chat.
  """
  def check_entry(chatter_params, client_ip, device_id) do
    username = chatter_params["username"]
    password = chatter_params["password"] || ""

    # 1. EARLY EXIT: IP Spam Check
    case Oneoffchat.RateLimit.hit("ip:#{client_ip}", :timer.minutes(15), 10) do
      {:deny, retry_after} ->
        {:error, :username,
         "Too many login attempts from your network. Please wait #{ceil(retry_after / 60_000)} minutes."}

      {:allow, _count} ->
        cond do
          # Regex to strictly enforce allowed characters.
          not String.match?(username, ~r/^[a-zA-Z0-9_]+$/) ->
            {:error, :username, "Username can only contain letters and numbers"}

          Accounts.is_banned?(username, client_ip) ->
            {:error, :username, "This account or IP address is permanently banned."}

          device_active?(device_id) ->
            {:error, :username, "You already have an active session in another tab."}

          username_active?(username) ->
            {:error, :username, "This username is already taken."}

          # 2. Targeted Account Brute-Force Check (e.g., 5 attempts per 5 minutes)
          Accounts.chatter_registered?(username) ->
            case Oneoffchat.RateLimit.hit("user:#{username}", :timer.minutes(5), 5) do
              {:allow, _count} ->
                case Accounts.authenticate_chatter(username, password) do
                  {:ok, chatter} -> {:ok, chatter}
                  {:error, _} -> {:error, :password, "Invalid password for this registered name."}
                end

              {:deny, retry_after} ->
                {:error, :password,
                 "Account locked due to too many failed attempts. Try again in #{ceil(retry_after / 60_000)} minutes."}
            end

          true ->
            # Fetch the registered user or create the transient guest struct
            chatter =
              Accounts.get_chatter_by_username(username) ||
                %Accounts.Chatter{username: username, is_admin: false}

            {:ok, chatter}
        end
    end
  end

  @doc """
  Checks if a specific device ID is already active in any of the available rooms.
  """
  def device_active?(device_id) do
    Enum.any?(@available_rooms, fn room ->
      Presence.list("chat:#{room}")
      |> Enum.any?(fn {_username, data} ->
        Enum.any?(data.metas, fn meta -> Map.get(meta, :device_id) == device_id end)
      end)
    end)
  end

  @doc """
  Checks if a username is currently taken in any room.
  """
  def username_active?(username) do
    Enum.any?(@available_rooms, fn room ->
      Map.has_key?(Presence.list("chat:#{room}"), username)
    end)
  end

  @doc """
  Checks if a user accepts DMs.
  """
  def accepts_dms?(username) do
    case Presence.get_by_key("users:global", username) do
      [] ->
        nil

      %{metas: metas} ->
        Enum.any?(metas, fn meta -> Map.get(meta, :accepts_dms, true) end)
    end
  end

  @doc """
  Checks if the sender is blocked by the receiver.
  """
  def has_blocked?(target_user, sender_username) do
    case Presence.get_by_key("users:global", target_user) do
      [] ->
        false

      %{metas: metas} ->
        Enum.any?(metas, fn meta ->
          sender_username in Map.get(meta, :ignored_chatters, [])
        end)
    end
  end
end
