defmodule ScriptVoice.Collectives.Collective do
  @moduledoc """
  Collective schema for ScriptVoice.

  Collectives are groups of voice artists who can work together on recordings.
  Each collective has a creator (admin) and can have multiple members.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "collectives" do
    field :name, :string
    field :slug, :string
    field :bio, :string
    field :avatar_url, :string
    field :profile_video_url, :string
    field :social_links, {:array, :string}, default: []
    field :is_accepting_commissions, :boolean, default: true

    belongs_to :creator, ScriptVoice.Accounts.User
    has_many :memberships, ScriptVoice.Collectives.CollectiveMembership
    has_many :members, through: [:memberships, :user]
    has_many :audio_versions, ScriptVoice.Audio.AudioVersion

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a collective.
  """
  def changeset(collective, attrs) do
    collective
    |> cast(attrs, [:name, :bio, :avatar_url, :profile_video_url,
                    :social_links, :is_accepting_commissions, :creator_id])
    |> validate_required([:name, :creator_id])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:bio, max: 500)
    |> generate_slug()
    |> unique_constraint(:slug)
  end

  @doc """
  Changeset for updating collective profile.
  """
  def profile_changeset(collective, attrs) do
    collective
    |> cast(attrs, [:name, :bio, :avatar_url, :profile_video_url,
                    :social_links, :is_accepting_commissions])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:bio, max: 500)
    |> maybe_update_slug()
    |> unique_constraint(:slug)
  end

  # Generate URL-friendly slug from name
  defp generate_slug(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, slugify(name))
    end
  end

  # Only update slug if name changed
  defp maybe_update_slug(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, slugify(name))
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  @doc """
  Returns the member count for a collective.
  """
  def member_count(%__MODULE__{memberships: memberships}) when is_list(memberships) do
    length(memberships)
  end
  def member_count(_), do: 0
end
