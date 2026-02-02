defmodule ScriptVoice.Audio.AudioVersion do
  @moduledoc """
  AudioVersion schema for ScriptVoice.

  Audio versions are recordings of screenplays submitted by voice artists.
  They can be solo performances or ensemble performances.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @performer_types ~w(solo duo group)

  schema "audio_versions" do
    field :performer_type, :string, default: "solo"
    field :group_name, :string
    field :performers, {:array, :string}, default: []
    field :casting, :map, default: %{}  # %{"CHARACTER_NAME" => "performer_name"}
    field :audio_url, :string
    field :duration, :string  # Legacy: Format "MM:SS" - deprecated, use duration_seconds
    field :duration_seconds, :integer  # Duration in seconds (preferred)
    field :file_size_bytes, :integer  # File size for upload validation
    field :likes, :integer, default: 0
    field :author_pick, :boolean, default: false
    field :verified, :boolean, default: false  # All performers verified?
    field :date, :string  # Formatted date for display

    # Commission-related fields
    field :is_paid_commission, :boolean, default: false

    # Version tracking - which script version this was recorded for
    field :script_version, :integer, default: 1

    belongs_to :screenplay, ScriptVoice.Screenplays.Screenplay
    belongs_to :submitted_by, ScriptVoice.Accounts.User
    belongs_to :commission_request, ScriptVoice.Commissions.CommissionRequest

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating an audio version.
  """
  def changeset(audio_version, attrs) do
    audio_version
    |> cast(attrs, [
      :performer_type, :group_name, :performers, :casting,
      :audio_url, :duration, :duration_seconds, :file_size_bytes,
      :verified, :screenplay_id, :submitted_by_id,
      :commission_request_id, :is_paid_commission, :script_version
    ])
    |> validate_required([:performer_type, :audio_url, :screenplay_id, :submitted_by_id])
    |> validate_inclusion(:performer_type, @performer_types)
    |> validate_number(:duration_seconds, greater_than: 0)
    |> validate_performers()
    |> format_date()
    |> foreign_key_constraint(:screenplay_id)
    |> foreign_key_constraint(:submitted_by_id)
  end

  @doc """
  Changeset for updating like count.
  """
  def like_changeset(audio_version, change) do
    new_count = max(0, audio_version.likes + change)

    audio_version
    |> change(likes: new_count)
  end

  @doc """
  Changeset for toggling author pick.
  """
  def author_pick_changeset(audio_version, is_picked) do
    audio_version
    |> change(author_pick: is_picked)
  end

  @doc """
  Formats duration in seconds to a human-readable string.

  ## Examples

      iex> format_duration(125)
      "2:05"

      iex> format_duration(3665)
      "1:01:05"

      iex> format_duration(nil)
      nil
  """
  def format_duration(nil), do: nil
  def format_duration(seconds) when is_integer(seconds) and seconds >= 0 do
    hours = div(seconds, 3600)
    remaining = rem(seconds, 3600)
    minutes = div(remaining, 60)
    secs = rem(remaining, 60)

    if hours > 0 do
      "#{hours}:#{pad_zero(minutes)}:#{pad_zero(secs)}"
    else
      "#{minutes}:#{pad_zero(secs)}"
    end
  end
  def format_duration(_), do: nil

  defp pad_zero(n), do: String.pad_leading(Integer.to_string(n), 2, "0")

  @doc """
  Returns the display duration, preferring duration_seconds over legacy duration field.
  """
  def display_duration(%__MODULE__{duration_seconds: seconds}) when is_integer(seconds) do
    format_duration(seconds)
  end
  def display_duration(%__MODULE__{duration: duration}) when is_binary(duration) do
    duration
  end
  def display_duration(_), do: "Unknown"

  # Validate that performers are provided based on performer type
  defp validate_performers(changeset) do
    performer_type = get_field(changeset, :performer_type)
    performers = get_field(changeset, :performers) || []

    cond do
      performer_type == "solo" and length(performers) > 1 ->
        add_error(changeset, :performers, "solo performances should have at most one performer")

      performer_type == "duo" and length(performers) != 2 ->
        add_error(changeset, :performers, "duo performances should have exactly two performers")

      performer_type == "group" and length(performers) < 2 ->
        add_error(changeset, :performers, "group performances should have at least two performers")

      true ->
        changeset
    end
  end

  # Format the insertion date for display
  defp format_date(changeset) do
    if get_change(changeset, :inserted_at) || !get_field(changeset, :date) do
      date_str = Calendar.strftime(DateTime.utc_now(), "%b %d, %Y")
      put_change(changeset, :date, date_str)
    else
      changeset
    end
  end

  @doc """
  List of available performer types.
  """
  def performer_types, do: @performer_types
end
