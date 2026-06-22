defmodule Oneoffchat.Repo.Migrations.CreateBans do
  use Ecto.Migration

  def change do
    create table(:bans) do
      add :ip_address, :string, null: false
      add :username, :string
      add :device_id, :string
      add :reason, :string
      add :banned_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Indexes make lookup blazing fast when a user connects
    create index(:bans, [:ip_address])
    create index(:bans, [:username])
  end
end
