defmodule Oneoffchat.Chat.MessageParser do
  @moduledoc """
  Parses raw string commands and returns actionable tuples.
  """

  @doc """
  Parses the /register command with a password. Ensures the password is at least 6 characters long.
  """
  def parse("/register " <> password, _current_username) do
    if String.length(password) >= 6 do
      {:local, :register, password}
    else
      {:error, "Your password must be at least 6 characters long."}
    end
  end

  def parse("/kick " <> args, _username) do
    args = String.trim(args)

    # Split by the first space only
    case String.split(args, " ", parts: 2) do
      [target_username, reason] ->
        {:admin, :kick, target_username, String.trim(reason)}

      [target_username] ->
        {:admin, :kick, target_username, "No reason provided."}
    end
  end

  def parse("/kick", _username) do
    {:admin, :kick, "", ""}
  end

  def parse("/ban " <> args, _username) do
    args = String.trim(args)

    case String.split(args, " ", parts: 2) do
      [target_username, reason] ->
        {:admin, :ban, target_username, String.trim(reason)}

      [target_username] ->
        {:admin, :ban, target_username, "No reason provided."}
    end
  end

  def parse("/ban", _username) do
    {:admin, :ban, "", ""}
  end

  # In message_parser.ex
  def parse("/unban " <> target, _username) do
    {:admin, :unban, String.trim(target)}
  end

  def parse("/unban", _username) do
    {:admin, :unban, ""}
  end

  # The public API
  def parse(text, current_username) do
    text
    |> String.trim()
    |> do_parse(current_username)
  end

  # 1. Catch empty messages immediately
  defp do_parse("", _current_username) do
    {:error, "Message cannot be empty."}
  end

  # 2. Catch commands (starts with "/")
  defp do_parse("/" <> rest, current_username) do
    parsed = String.split(rest, " ", parts: 2)

    case parsed do
      [cmd, args] -> route_command(cmd, args, current_username)
      [cmd] -> route_command(cmd, nil, current_username)
    end
  end

  # 3. Catch-all for regular text (doesn't start with "/" and isn't empty)
  defp do_parse(regular_text, current_username) do
    {:broadcast, :chat_msg, regular_text, current_username}
  end

  # --------------------------------------------------------
  # ACTION COMMAND: /me dances
  # --------------------------------------------------------
  defp route_command("me", action, username) when is_binary(action) do
    clean_action = String.trim(action)

    if clean_action == "" do
      {:error, "Missing parameter."}
    else
      {:broadcast, :emote, clean_action, username}
    end
  end

  defp route_command("me", nil, _username) do
    {:error, "Missing parameter."}
  end

  # --------------------------------------------------------
  # LOCAL COMMAND: /clear
  # --------------------------------------------------------
  defp route_command("clear", _args, _username) do
    {:local, :clear}
  end

  # --------------------------------------------------------
  # ADMIN COMMAND: /system <msg>
  # --------------------------------------------------------
  defp route_command("system", message, _username) when is_binary(message) do
    {:broadcast, :system, message, "SYSTEM"}
  end

  defp route_command("register", _args, _username) do
    {:error, "Password is required."}
  end

  # --------------------------------------------------------
  # CATCH-ALL: Unknown Command
  # --------------------------------------------------------
  defp route_command(unknown_cmd, _args, _username) do
    {:error, "Unknown command: /#{unknown_cmd}"}
  end
end
