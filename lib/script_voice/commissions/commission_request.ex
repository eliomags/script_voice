defmodule ScriptVoice.Commissions.CommissionRequest do
  @moduledoc """
  Schema for commission requests between writers and performers.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending accepted declined in_progress submitted revision_requested completed cancelled disputed)

  schema "commission_requests" do
    field :status, :string, default: "pending"

    # Pricing (in cents)
    field :calculated_amount_cents, :integer
    field :offered_amount_cents, :integer
    field :agreed_amount_cents, :integer

    # Communication
    field :writer_message, :string
    field :performer_response, :string

    # Timeline
    field :deadline, :date
    field :is_rush, :boolean, default: false

    # Retakes
    field :retakes_included, :integer, default: 2
    field :retakes_used, :integer, default: 0

    # Result
    field :final_audio_version_id, :binary_id

    # Tracking timestamps
    field :accepted_at, :utc_datetime
    field :submitted_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :cancelled_at, :utc_datetime
    field :cancellation_reason, :string

    # Relationships
    belongs_to :screenplay, ScriptVoice.Screenplays.Screenplay
    belongs_to :writer, ScriptVoice.Accounts.User
    belongs_to :performer, ScriptVoice.Accounts.User
    belongs_to :cancelled_by_user, ScriptVoice.Accounts.User, foreign_key: :cancelled_by

    has_many :submissions, ScriptVoice.Commissions.CommissionSubmission
    has_many :messages, ScriptVoice.Commissions.CommissionMessage
    has_one :payment, ScriptVoice.Commissions.Payment

    timestamps()
  end

  @doc false
  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :screenplay_id,
      :writer_id,
      :performer_id,
      :status,
      :calculated_amount_cents,
      :offered_amount_cents,
      :agreed_amount_cents,
      :writer_message,
      :performer_response,
      :deadline,
      :is_rush,
      :retakes_included,
      :retakes_used,
      :final_audio_version_id,
      :accepted_at,
      :submitted_at,
      :completed_at,
      :cancelled_at,
      :cancelled_by,
      :cancellation_reason
    ])
    |> validate_required([:screenplay_id, :writer_id, :performer_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:offered_amount_cents, greater_than: 0)
    |> validate_number(:retakes_included, greater_than_or_equal_to: 0)
    |> validate_number(:retakes_used, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:screenplay_id)
    |> foreign_key_constraint(:writer_id)
    |> foreign_key_constraint(:performer_id)
  end

  @doc """
  Changeset for creating a new commission request.
  """
  def create_changeset(request, attrs) do
    request
    |> changeset(attrs)
    |> validate_required([:writer_message, :offered_amount_cents])
    |> put_change(:status, "pending")
  end

  @doc """
  Changeset for accepting a commission.
  """
  def accept_changeset(request, attrs \\ %{}) do
    request
    |> cast(attrs, [:performer_response, :agreed_amount_cents])
    |> put_change(:status, "accepted")
    |> put_change(:accepted_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Changeset for declining a commission.
  """
  def decline_changeset(request, attrs \\ %{}) do
    request
    |> cast(attrs, [:performer_response])
    |> put_change(:status, "declined")
  end

  @doc """
  Changeset for cancelling a commission.
  """
  def cancel_changeset(request, cancelled_by_id, reason) do
    request
    |> put_change(:status, "cancelled")
    |> put_change(:cancelled_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> put_change(:cancelled_by, cancelled_by_id)
    |> put_change(:cancellation_reason, reason)
  end

  @doc """
  Changeset for marking commission as in progress.
  """
  def in_progress_changeset(request) do
    put_change(request, :status, "in_progress")
  end

  @doc """
  Changeset for marking commission as submitted.
  """
  def submitted_changeset(request) do
    request
    |> put_change(:status, "submitted")
    |> put_change(:submitted_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Changeset for requesting revision.
  """
  def revision_changeset(request) do
    request
    |> put_change(:status, "revision_requested")
    |> update_change(:retakes_used, &(&1 + 1))
  end

  @doc """
  Changeset for completing commission.
  """
  def complete_changeset(request, final_audio_version_id) do
    request
    |> put_change(:status, "completed")
    |> put_change(:completed_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> put_change(:final_audio_version_id, final_audio_version_id)
  end

  @doc """
  Returns all valid statuses.
  """
  def statuses, do: @statuses

  @doc """
  Returns statuses that allow cancellation.
  """
  def cancellable_statuses, do: ~w(pending accepted in_progress)

  @doc """
  Checks if the commission can be cancelled.
  """
  def cancellable?(%__MODULE__{status: status}) do
    status in cancellable_statuses()
  end

  @doc """
  Checks if more retakes are available.
  """
  def retakes_available?(%__MODULE__{retakes_included: included, retakes_used: used}) do
    used < included
  end

  @doc """
  Formats amount in cents to dollars string.
  """
  def format_amount(nil), do: nil
  def format_amount(cents), do: "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"
end
