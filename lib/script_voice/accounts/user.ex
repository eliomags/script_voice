defmodule ScriptVoice.Accounts.User do
  @moduledoc """
  User schema for ScriptVoice.

  Users can be writers, voice artists, or visitors.
  Verification can be done via phone or email.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @user_types ~w(writer voice_artist visitor)
  @verification_statuses ~w(unverified pending verified flagged)
  @performer_types ~w(solo group)

  schema "users" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :password_hash, :string
    field :password, :string, virtual: true

    # User type and verification
    field :user_type, :string, default: "visitor"
    field :verification_status, :string, default: "unverified"
    field :verification_video_url, :string
    field :verification_phrase, :string  # The phrase they read aloud
    field :verified_via, :string  # "phone" or "email"
    field :verified_at, :utc_datetime

    # Voice artist specific fields
    field :performer_type, :string  # "solo" or "group"
    field :group_name, :string

    # Social links stored as JSON array
    field :social_links, {:array, :string}, default: []

    # Group members (for ensemble accounts) - stored as JSON
    field :group_members, {:array, :map}, default: []

    has_many :screenplays, ScriptVoice.Screenplays.Screenplay, foreign_key: :writer_id
    has_many :audio_versions, ScriptVoice.Audio.AudioVersion, foreign_key: :submitted_by_id
    has_many :likes, ScriptVoice.Social.Like

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new user during registration.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name, :email, :phone, :password, :user_type,
      :verification_status, :verification_video_url, :verification_phrase,
      :verified_via, :verified_at, :performer_type, :social_links
    ])
    |> validate_required([:name, :user_type])
    |> validate_contact_info()
    |> validate_inclusion(:user_type, @user_types)
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:password, min: 6, max: 72)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_format(:phone, ~r/^\+?[1-9]\d{1,14}$/, message: "must be a valid phone number")
    |> unique_constraint(:email)
    |> unique_constraint(:phone)
    |> maybe_hash_password()
  end

  @doc """
  Changeset for verification (completing the verification process).
  """
  def verification_changeset(user, attrs) do
    user
    |> cast(attrs, [:verification_status, :verification_video_url, :verification_phrase, :verified_via, :verified_at])
    |> validate_inclusion(:verification_status, @verification_statuses)
    |> validate_inclusion(:verified_via, ["phone", "email"])
  end

  @doc """
  Changeset for voice artist profile setup.
  """
  def voice_artist_changeset(user, attrs) do
    user
    |> cast(attrs, [:performer_type, :group_name, :group_members])
    |> validate_inclusion(:performer_type, @performer_types)
    |> validate_group_name()
  end

  @doc """
  Changeset for updating user profile.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :phone, :social_links])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_format(:phone, ~r/^\+?[1-9]\d{1,14}$/, message: "must be a valid phone number")
    |> unique_constraint(:email)
    |> unique_constraint(:phone)
  end

  # Validate that at least email or phone is provided
  defp validate_contact_info(changeset) do
    email = get_field(changeset, :email)
    phone = get_field(changeset, :phone)

    if is_nil(email) and is_nil(phone) do
      add_error(changeset, :email, "either email or phone is required")
    else
      changeset
    end
  end

  # Validate group name is required for group performer type
  defp validate_group_name(changeset) do
    performer_type = get_field(changeset, :performer_type)
    group_name = get_field(changeset, :group_name)

    if performer_type == "group" and (is_nil(group_name) or group_name == "") do
      add_error(changeset, :group_name, "is required for group accounts")
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset) do
    password = get_change(changeset, :password)

    if password && changeset.valid? do
      changeset
      |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Verifies the password against the stored hash.
  """
  def valid_password?(%__MODULE__{password_hash: hash}, password)
      when is_binary(hash) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hash)
  end

  def valid_password?(_, _), do: false

  @doc """
  Returns true if user is verified.
  """
  def verified?(%__MODULE__{verification_status: status}) do
    status == "verified"
  end
end
