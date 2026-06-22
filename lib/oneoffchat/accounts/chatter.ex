defmodule Oneoffchat.Accounts.Chatter do
  use Ecto.Schema
  import Ecto.Changeset

  @reserved_usernames ["admin", "superadmin", "mod", "system", "owner"]

  schema "chatters" do
    field :username, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :is_admin, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chatter, attrs) do
    chatter
    # FIX 1: Only cast safe fields. Removed :password and :is_admin.
    |> cast(attrs, [:username])
    |> validate_required(:username, message: "Username is required")
    |> validate_length(:username, min: 3, message: "Username must be at least 3 characters")
    |> validate_length(:username, max: 15, message: "Username must be at most 15 characters")
    |> validate_format(:username, ~r/^[a-zA-Z0-9]+$/,
      message: "Username can only contain letters and numbers"
    )
    |> validate_not_reserved(:username)
  end

  # Used strictly by your /register command
  def registration_changeset(chatter, attrs) do
    chatter
    # Run the base username validations
    |> changeset(attrs)
    |> cast(attrs, [:password])
    |> validate_required([:password], message: "Password is required to register")
    |> validate_length(:password, min: 6, message: "Password must be at least 6 characters")
    |> unsafe_validate_unique(:username, Oneoffchat.Repo, message: "Username is already registered")
    |> unique_constraint(:username)
    |> hash_password()
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(password))
    end
  end

  defp validate_not_reserved(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      # Downcase the input strictly for the comparison
      if String.downcase(value) in @reserved_usernames do
        [{field, "This username isn't available"}]
      else
        # Return an empty list if valid
        []
      end
    end)
  end
end
