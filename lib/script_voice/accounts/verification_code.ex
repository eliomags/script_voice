defmodule ScriptVoice.Accounts.VerificationCode do
  @moduledoc """
  Schema for storing verification codes sent via SMS or email.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @code_types ~w(phone email)

  schema "verification_codes" do
    field :code, :string
    field :type, :string  # "phone" or "email"
    field :target, :string  # phone number or email address
    field :expires_at, :utc_datetime
    field :verified_at, :utc_datetime
    field :attempts, :integer, default: 0

    belongs_to :user, ScriptVoice.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new verification code.
  """
  def changeset(code, attrs) do
    code
    |> cast(attrs, [:code, :type, :target, :expires_at, :user_id])
    |> validate_required([:code, :type, :target, :expires_at])
    |> validate_inclusion(:type, @code_types)
    |> validate_length(:code, is: 6)
  end

  @doc """
  Changeset for recording a verification attempt.
  """
  def attempt_changeset(code, attrs) do
    code
    |> cast(attrs, [:attempts, :verified_at])
  end

  @doc """
  Check if the code has expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Check if too many attempts have been made.
  """
  def too_many_attempts?(%__MODULE__{attempts: attempts}) do
    attempts >= 5
  end

  @doc """
  Generate a random 6-digit code.
  """
  def generate_code do
    :rand.uniform(999_999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  @doc """
  Generate expiration time (15 minutes from now).
  """
  def generate_expiration do
    DateTime.utc_now()
    |> DateTime.add(15 * 60, :second)
    |> DateTime.truncate(:second)
  end
end
