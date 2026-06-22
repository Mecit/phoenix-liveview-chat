defmodule Oneoffchat.Chat.MessageParserTest do
  use ExUnit.Case, async: true
  alias Oneoffchat.Chat.MessageParser

  describe "parse/2" do
    test "successfully parses the /me command" do
      # Act
      result = MessageParser.parse("/me dances in the rain", "TestUser")

      # Assert
      assert result == {:broadcast, :emote, "dances in the rain", "TestUser"}
    end

    test "returns missing parameter error for empty /me command" do
      assert MessageParser.parse("/me", "TestUser") == {:error, "Missing parameter."}
      assert MessageParser.parse("/me   ", "TestUser") == {:error, "Missing parameter."}
    end

    test "successfully parses the /clear command" do
      assert MessageParser.parse("/clear", "TestUser") == {:local, :clear}
    end

    test "returns an error for completely unknown commands" do
      assert MessageParser.parse("/dance", "TestUser") == {:error, "Unknown command: /dance"}
    end
  end
end
