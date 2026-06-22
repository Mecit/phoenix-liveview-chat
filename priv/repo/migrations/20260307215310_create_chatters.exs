defmodule Oneoffchat.Repo.Migrations.CreateChatters do
  use Ecto.Migration

  def change do
    create table(:chatters) do
      add :username, :string, collate: :nocase
      add :hashed_password, :string
      add :is_admin, :boolean, default: false

      timestamps(type: :utc_datetime)
    end
  end
end
