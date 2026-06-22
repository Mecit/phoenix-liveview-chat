defmodule Oneoffchat.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :type, :string, null: false, default: "chat_msg"
      add :username, :string
      add :text, :text
      add :room, :string
      timestamps(type: :utc_datetime)
    end
  end
end
