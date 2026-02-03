defmodule ScriptVoice.Collectives.CollectiveMembership do
  @moduledoc """
  CollectiveMembership schema for ScriptVoice.

  Represents a user's membership in a collective with their role.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(admin member)

  schema "collective_memberships" do
    field :role, :string, default: "member"
    field :display_order, :integer, default: 0
    field :joined_at, :utc_datetime

    belongs_to :collective, ScriptVoice.Collectives.Collective
    belongs_to :user, ScriptVoice.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a membership.
  """
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :display_order, :collective_id, :user_id])
    |> validate_required([:collective_id, :user_id])
    |> validate_inclusion(:role, @roles)
    |> put_joined_at()
    |> unique_constraint([:collective_id, :user_id],
        name: :collective_memberships_collective_id_user_id_index,
        message: "already a member of this collective")
  end

  @doc """
  Changeset for updating role only.
  """
  def role_changeset(membership, role) do
    membership
    |> change(role: role)
    |> validate_inclusion(:role, @roles)
  end

  defp put_joined_at(changeset) do
    if get_field(changeset, :joined_at) do
      changeset
    else
      put_change(changeset, :joined_at, DateTime.utc_now() |> DateTime.truncate(:second))
    end
  end

  @doc """
  List of valid roles.
  """
  def roles, do: @roles

  @doc """
  Check if role is admin.
  """
  def admin?(%__MODULE__{role: "admin"}), do: true
  def admin?(_), do: false
end
