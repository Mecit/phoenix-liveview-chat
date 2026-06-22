defmodule Oneoffchat.ChatFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Oneoffchat.Chat` context.
  """

  @doc """
  Generate a message.
  """
  def message_fixture(attrs \\ %{}) do
    {:ok, message} =
      attrs
      |> Enum.into(%{
        username: "some username"
      })
      |> Oneoffchat.Chat.create_message()

    message
  end
end
