defmodule ScriptVoice.Commissions.CommissionSubmission do
  @moduledoc """
  Schema for audio submissions within a commission.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending_review approved revision_requested)

  schema "commission_submissions" do
    field :audio_url, :string
    field :duration, :integer  # in seconds
    field :file_size_bytes, :integer

    field :submission_number, :integer
    field :performer_notes, :string

    field :status, :string, default: "pending_review"
    field :writer_feedback, :string
    field :reviewed_at, :utc_datetime

    belongs_to :commission_request, ScriptVoice.Commissions.CommissionRequest

    timestamps()
  end

  @doc false
  def changeset(submission, attrs) do
    submission
    |> cast(attrs, [
      :commission_request_id,
      :audio_url,
      :duration,
      :file_size_bytes,
      :submission_number,
      :performer_notes,
      :status,
      :writer_feedback,
      :reviewed_at
    ])
    |> validate_required([:commission_request_id, :audio_url, :submission_number])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:submission_number, greater_than: 0)
    |> validate_number(:duration, greater_than: 0)
    |> validate_number(:file_size_bytes, greater_than: 0)
    |> foreign_key_constraint(:commission_request_id)
  end

  @doc """
  Changeset for creating a new submission.
  """
  def create_changeset(submission, attrs) do
    submission
    |> changeset(attrs)
    |> put_change(:status, "pending_review")
  end

  @doc """
  Changeset for approving a submission.
  """
  def approve_changeset(submission) do
    submission
    |> put_change(:status, "approved")
    |> put_change(:reviewed_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Changeset for requesting revision on a submission.
  """
  def revision_changeset(submission, feedback) do
    submission
    |> put_change(:status, "revision_requested")
    |> put_change(:writer_feedback, feedback)
    |> put_change(:reviewed_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Returns all valid statuses.
  """
  def statuses, do: @statuses

  @doc """
  Formats duration in seconds to mm:ss string.
  """
  def format_duration(nil), do: nil
  def format_duration(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end
end
