defmodule Oneoffchat.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Oneoffchat.Accounts` context.
  """

  @doc """
  Generate a chatter.
  """
  def chatter_fixture(attrs \\ %{}) do
    {:ok, chatter} =
      attrs
      |> Enum.into(%{
        hashed_password: "some hashed_password",
        username: "some username"
      })
      |> Oneoffchat.Accounts.register_chatter()

    chatter
  end
end
