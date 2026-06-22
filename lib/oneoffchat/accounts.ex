defmodule Oneoffchat.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Oneoffchat.Repo
  alias Oneoffchat.Accounts.Chatter
  alias Oneoffchat.Accounts.Ban

  @doc """
  Returns the list of chatters.

  ## Examples

      iex> list_chatters()
      [%Chatter{}, ...]

  """
  def list_chatters do
    Repo.all(Chatter)
  end

  @doc """
  Gets a single chatter.

  Raises `Ecto.NoResultsError` if the Chatter does not exist.

  ## Examples

      iex> get_chatter!(123)
      %Chatter{}

      iex> get_chatter!(456)
      ** (Ecto.NoResultsError)

  """
  def get_chatter!(id), do: Repo.get!(Chatter, id)
  def get_chatter_by_username(username), do: Repo.get_by(Chatter, username: username)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking chatter changes.

  ## Examples

      iex> change_chatter(chatter)
      %Ecto.Changeset{data: %Chatter{}}

  """
  def change_chatter(%Chatter{} = chatter, attrs \\ %{}) do
    Chatter.changeset(chatter, attrs)
  end

  # ---
  # Called by the LiveView when /register is typed
  def register_chatter(attrs) do
    %Chatter{}
    |> Chatter.registration_changeset(attrs)
    |> Repo.insert()
  end

  # Called by the login form as the user types
  def chatter_registered?(username) do
    # We check if the name exists in the DB AND actually has a password
    Repo.exists?(
      from c in Chatter,
        where: c.username == ^username and not is_nil(c.hashed_password)
    )
  end

  # Called when a registered user submits the login form
  def authenticate_chatter(username, password) do
    chatter = Repo.get_by(Chatter, username: username)

    cond do
      chatter && Bcrypt.verify_pass(password, chatter.hashed_password) ->
        {:ok, chatter}

      chatter ->
        {:error, :unauthorized}

      true ->
        # Bcrypt.no_user_verify() helps prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :not_found}
    end
  end

  def ban_user(attrs \\ %{}) do
    %Ban{}
    |> Ban.changeset(attrs)
    |> Repo.insert()
  end

  def ip_banned?(ip_address) do
    Repo.exists?(
      from b in Ban,
        where: b.ip_address == ^ip_address
    )
  end

  @doc """
  Checks if a given username OR IP address currently exists in the bans table.
  """
  def is_banned?(username, ip_address) do
    query =
      from b in Ban,
        where: b.username == ^username or b.ip_address == ^ip_address

    Repo.exists?(query)
  end

  def unban_user(identifier) do
    # Search for a match on either the username or the IP address
    query =
      from b in Ban,
        where: b.username == ^identifier or b.ip_address == ^identifier

    # Repo.delete_all returns {number_of_deleted_rows, nil}
    case Repo.delete_all(query) do
      {0, nil} -> {:error, :not_found}
      {count, nil} -> {:ok, count}
    end
  end

  def normalize_ip(ip_string) when is_binary(ip_string) do
    case ip_string |> String.to_charlist() |> :inet.parse_address() do
      {:ok, ip_tuple} ->
        # Converts the tuple back into a perfectly uniform, lowercase string
        ip_tuple |> :inet.ntoa() |> to_string()

      {:error, _} ->
        # Fallback just in case a malformed string gets passed
        ip_string |> String.trim() |> String.downcase()
    end
  end
end
