defmodule Oneoffchat.Chat.RateLimiter do
  @moduledoc """
  Provides a simple rate-limiting mechanism to prevent users from sending too many messages
  in a short period of time.
  """
  @window_seconds 15
  @max_messages 5

  def check_rate(timestamps, cooldown_until, now \\ System.system_time(:second)) do
    recent = Enum.filter(timestamps, &((now - &1) <= @window_seconds))

    cond do
      cooldown_until && cooldown_until > now ->
        {:error, :in_cooldown, cooldown_until - now, recent}

      length(recent) >= @max_messages ->
        {:error, :rate_limited, @window_seconds, []}

      true ->
        {:ok, [now | recent]}
    end
  end
end
