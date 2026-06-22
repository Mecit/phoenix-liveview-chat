defmodule Oneoffchat.Repo.Migrations.CreatePrivateMessages do
  use Ecto.Migration

  def change do
    create table(:private_messages) do
      add :username, :string, null: false
      add :receiver, :string, null: false
      add :text, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    # Optimize for two-way conversation queries
    create index(:private_messages, [:username, :receiver])
    create index(:private_messages, [:receiver, :username])
  end
end
