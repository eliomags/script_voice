defmodule ScriptVoice.Accounts do
  @moduledoc """
  The Accounts context manages users, authentication, and verification.

  Supports verification via phone (SMS) or email.
  """

  import Ecto.Query, warn: false
  alias ScriptVoice.Repo
  alias ScriptVoice.Accounts.{User, VerificationCode}

  # ============================================================================
  # USER CRUD
  # ============================================================================

  @doc """
  Returns the list of users.

  ## Options
    * `:user_type` - Filter by user type (e.g., "writer", "voice_artist")
    * `:verification_status` - Filter by verification status
  """
  def list_users(opts \\ []) do
    User
    |> maybe_filter_by_user_type(Keyword.get(opts, :user_type))
    |> maybe_filter_by_verification(Keyword.get(opts, :verification_status))
    |> Repo.all()
  end

  defp maybe_filter_by_user_type(query, nil), do: query
  defp maybe_filter_by_user_type(query, user_type) do
    from(u in query, where: u.user_type == ^user_type)
  end

  defp maybe_filter_by_verification(query, nil), do: query
  defp maybe_filter_by_verification(query, status) do
    from(u in query, where: u.verification_status == ^status)
  end

  @doc """
  Searches voice artists by name.
  """
  def search_voice_artists(search_term) when is_binary(search_term) do
    search_pattern = "%#{search_term}%"

    User
    |> where([u], u.user_type == "voice_artist")
    |> where([u], ilike(u.name, ^search_pattern))
    |> order_by([u], asc: u.name)
    |> limit(10)
    |> Repo.all()
  end

  @doc """
  Gets a single user.
  Returns nil if the User does not exist.
  """
  def get_user(id) when is_binary(id) do
    Repo.get(User, id)
  end

  def get_user(_), do: nil

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  @doc """
  Gets a user by phone.
  """
  def get_user_by_phone(phone) when is_binary(phone) do
    Repo.get_by(User, phone: phone)
  end

  @doc """
  Gets a user by email and password.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Registers a new user.
  """
  def register_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user's profile.
  """
  def update_user_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a user's verification status.
  """
  def update_user_verification(%User{} = user, attrs) do
    user
    |> User.verification_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Sets up a voice artist profile.
  """
  def setup_voice_artist(%User{} = user, attrs) do
    user
    |> User.voice_artist_changeset(Map.put(attrs, "user_type", "voice_artist"))
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  # ============================================================================
  # VERIFICATION CODES
  # ============================================================================

  @doc """
  Creates and sends a verification code.
  Returns {:ok, verification_code} or {:error, reason}
  """
  def create_verification_code(user_id, type, target) when type in ["phone", "email"] do
    # Invalidate any existing codes for this target
    from(vc in VerificationCode,
      where: vc.target == ^target and vc.type == ^type and is_nil(vc.verified_at)
    )
    |> Repo.delete_all()

    # Create new code
    code = VerificationCode.generate_code()
    expires_at = VerificationCode.generate_expiration()

    %VerificationCode{}
    |> VerificationCode.changeset(%{
      code: code,
      type: type,
      target: target,
      expires_at: expires_at,
      user_id: user_id
    })
    |> Repo.insert()
    |> case do
      {:ok, verification_code} ->
        # In production, send SMS or email here
        send_verification_code(verification_code)
        {:ok, verification_code}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Verifies a code and marks the user as verified.
  """
  def verify_code(target, type, submitted_code) do
    # Find the most recent unexpired code for this target
    query =
      from(vc in VerificationCode,
        where:
          vc.target == ^target and
            vc.type == ^type and
            is_nil(vc.verified_at) and
            vc.expires_at > ^DateTime.utc_now(),
        order_by: [desc: vc.inserted_at],
        limit: 1
      )

    case Repo.one(query) do
      nil ->
        {:error, :code_not_found}

      verification_code ->
        cond do
          VerificationCode.too_many_attempts?(verification_code) ->
            {:error, :too_many_attempts}

          verification_code.code != submitted_code ->
            # Increment attempts
            verification_code
            |> VerificationCode.attempt_changeset(%{attempts: verification_code.attempts + 1})
            |> Repo.update()

            {:error, :invalid_code}

          true ->
            # Code is correct - mark as verified
            verification_code
            |> VerificationCode.attempt_changeset(%{verified_at: DateTime.utc_now()})
            |> Repo.update()

            # If user exists, update their verification status
            if verification_code.user_id do
              user = get_user(verification_code.user_id)

              if user do
                update_user_verification(user, %{
                  verification_status: "verified",
                  verified_via: type,
                  verified_at: DateTime.utc_now()
                })
              end
            end

            {:ok, verification_code}
        end
    end
  end

  @doc """
  Checks if a verification code is still valid.
  """
  def valid_verification_code?(target, type) do
    query =
      from(vc in VerificationCode,
        where:
          vc.target == ^target and
            vc.type == ^type and
            is_nil(vc.verified_at) and
            vc.expires_at > ^DateTime.utc_now(),
        limit: 1
      )

    Repo.exists?(query)
  end

  # Placeholder for sending verification code
  # In production, integrate with Twilio for SMS or SendGrid/SES for email
  defp send_verification_code(%VerificationCode{type: "phone", target: phone, code: code}) do
    # TODO: Integrate with SMS provider (Twilio, etc.)
    IO.puts("📱 SMS to #{phone}: Your ScriptVoice verification code is: #{code}")
    :ok
  end

  defp send_verification_code(%VerificationCode{type: "email", target: email, code: code}) do
    # TODO: Integrate with email provider
    IO.puts("📧 Email to #{email}: Your ScriptVoice verification code is: #{code}")
    :ok
  end

  # ============================================================================
  # VIDEO VERIFICATION
  # ============================================================================

  @doc """
  Generates a random phrase for video verification.
  """
  def generate_verification_phrase do
    phrases = [
      "The quick brown fox jumps over the lazy dog",
      "Pack my box with five dozen liquor jugs",
      "How vexingly quick daft zebras jump",
      "The five boxing wizards jump quickly",
      "Sphinx of black quartz judge my vow"
    ]

    Enum.random(phrases)
  end

  @doc """
  Stores the video verification URL and marks user as pending.
  """
  def submit_video_verification(%User{} = user, video_url) do
    user
    |> User.verification_changeset(%{
      verification_video_url: video_url,
      verification_status: "pending"
    })
    |> Repo.update()
  end

  @doc """
  Completes the full verification process (code + video for writers/voice artists).
  """
  def complete_verification(%User{} = user, attrs) do
    verification_attrs = %{
      verification_status: "verified",
      verified_via: attrs[:verified_via],
      verified_at: DateTime.utc_now(),
      verification_video_url: attrs[:video_url]
    }

    user
    |> User.verification_changeset(verification_attrs)
    |> Repo.update()
  end
end
