defmodule Oneoffchat.AccountsTest do
  use Oneoffchat.DataCase

  alias Oneoffchat.Accounts

  describe "chatters" do
    alias Oneoffchat.Accounts.Chatter

    import Oneoffchat.AccountsFixtures

    @invalid_attrs %{username: nil, hashed_password: nil}

    test "list_chatters/0 returns all chatters" do
      chatter = chatter_fixture()
      assert Accounts.list_chatters() == [chatter]
    end

    test "get_chatter!/1 returns the chatter with given id" do
      chatter = chatter_fixture()
      assert Accounts.get_chatter!(chatter.id) == chatter
    end

    test "create_chatter/1 with valid data creates a chatter" do
      valid_attrs = %{username: "some username", hashed_password: "some hashed_password"}

      assert {:ok, %Chatter{} = chatter} = Accounts.create_chatter(valid_attrs)
      assert chatter.username == "some username"
      assert chatter.hashed_password == "some hashed_password"
    end

    test "create_chatter/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_chatter(@invalid_attrs)
    end

    test "update_chatter/2 with valid data updates the chatter" do
      chatter = chatter_fixture()

      update_attrs = %{
        username: "some updated username",
        hashed_password: "some updated hashed_password"
      }

      assert {:ok, %Chatter{} = chatter} = Accounts.update_chatter(chatter, update_attrs)
      assert chatter.username == "some updated username"
      assert chatter.hashed_password == "some updated hashed_password"
    end

    test "update_chatter/2 with invalid data returns error changeset" do
      chatter = chatter_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_chatter(chatter, @invalid_attrs)
      assert chatter == Accounts.get_chatter!(chatter.id)
    end

    test "delete_chatter/1 deletes the chatter" do
      chatter = chatter_fixture()
      assert {:ok, %Chatter{}} = Accounts.delete_chatter(chatter)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_chatter!(chatter.id) end
    end

    test "change_chatter/1 returns a chatter changeset" do
      chatter = chatter_fixture()
      assert %Ecto.Changeset{} = Accounts.change_chatter(chatter)
    end
  end
end
