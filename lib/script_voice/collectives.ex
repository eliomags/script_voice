defmodule ScriptVoice.Collectives do
  @moduledoc """
  Context for managing collectives and memberships.

  Collectives allow voice artists to group together and submit
  audio versions as a team while maintaining individual profiles.
  """
  import Ecto.Query
  alias ScriptVoice.Repo
  alias ScriptVoice.Collectives.{Collective, CollectiveMembership, CollectiveInvitation, CollectiveJoinRequest, JoinRequestMessage}

  # ============================================
  # COLLECTIVE CRUD
  # ============================================

  @doc """
  Lists all collectives with optional filtering.

  Options:
  - `:member_id` - Filter to collectives where user is a member
  - `:accepting_commissions` - Filter by commission status
  """
  def list_collectives(opts \\ []) do
    Collective
    |> maybe_filter_by_member(opts[:member_id])
    |> maybe_filter_accepting(opts[:accepting_commissions])
    |> preload([:creator, memberships: :user])
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a collective by ID.
  """
  def get_collective(id) do
    Collective
    |> Repo.get(id)
    |> Repo.preload([:creator, memberships: [user: []]])
  end

  @doc """
  Gets a collective by slug.
  """
  def get_collective_by_slug(slug) do
    Collective
    |> Repo.get_by(slug: slug)
    |> Repo.preload([:creator, memberships: [user: []]])
  end

  @doc """
  Creates a new collective. The creator is automatically added as admin.
  """
  def create_collective(attrs, creator) do
    %Collective{}
    |> Collective.changeset(Map.put(attrs, "creator_id", creator.id))
    |> Repo.insert()
    |> case do
      {:ok, collective} ->
        # Auto-add creator as admin member
        {:ok, _membership} = add_member(collective, creator, "admin")
        {:ok, Repo.preload(collective, [:creator, memberships: :user])}

      error ->
        error
    end
  end

  @doc """
  Updates a collective's profile.
  """
  def update_collective(%Collective{} = collective, attrs) do
    collective
    |> Collective.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a collective.
  """
  def delete_collective(%Collective{} = collective) do
    Repo.delete(collective)
  end

  # ============================================
  # MEMBERSHIP MANAGEMENT
  # ============================================

  @doc """
  Adds a user as a member of a collective.
  """
  def add_member(%Collective{} = collective, user, role \\ "member") do
    %CollectiveMembership{}
    |> CollectiveMembership.changeset(%{
      collective_id: collective.id,
      user_id: user.id,
      role: role
    })
    |> Repo.insert()
  end

  @doc """
  Removes a user from a collective.
  """
  def remove_member(%Collective{} = collective, user) do
    from(m in CollectiveMembership,
      where: m.collective_id == ^collective.id and m.user_id == ^user.id
    )
    |> Repo.delete_all()
    |> case do
      {count, _} when count > 0 -> :ok
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Updates a member's role in a collective.
  """
  def update_member_role(%Collective{} = collective, user, role) do
    case get_membership(collective.id, user.id) do
      nil ->
        {:error, :not_found}

      membership ->
        membership
        |> CollectiveMembership.role_changeset(role)
        |> Repo.update()
    end
  end

  @doc """
  Lists all members of a collective ordered by display_order.
  """
  def list_members(%Collective{} = collective) do
    CollectiveMembership
    |> where([m], m.collective_id == ^collective.id)
    |> order_by([m], [asc: m.display_order, asc: m.joined_at])
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Lists all collectives a user is a member of.
  """
  def list_collectives_for_user(user_id) do
    CollectiveMembership
    |> where([m], m.user_id == ^user_id)
    |> preload(collective: [:creator, memberships: :user])
    |> order_by([m], desc: m.joined_at)
    |> Repo.all()
    |> Enum.map(& &1.collective)
  end

  @doc """
  Checks if a user is a member of a collective.
  """
  def is_member?(collective_id, user_id) do
    CollectiveMembership
    |> where([m], m.collective_id == ^collective_id and m.user_id == ^user_id)
    |> Repo.exists?()
  end

  @doc """
  Checks if a user is an admin of a collective.
  """
  def is_admin?(collective_id, user_id) do
    CollectiveMembership
    |> where([m], m.collective_id == ^collective_id and m.user_id == ^user_id and m.role == "admin")
    |> Repo.exists?()
  end

  @doc """
  Gets a specific membership.
  """
  def get_membership(collective_id, user_id) do
    CollectiveMembership
    |> where([m], m.collective_id == ^collective_id and m.user_id == ^user_id)
    |> preload([:collective, :user])
    |> Repo.one()
  end

  @doc """
  Counts members in a collective.
  """
  def member_count(collective_id) do
    CollectiveMembership
    |> where([m], m.collective_id == ^collective_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Counts admins in a collective.
  """
  def admin_count(collective_id) do
    CollectiveMembership
    |> where([m], m.collective_id == ^collective_id and m.role == "admin")
    |> Repo.aggregate(:count)
  end

  @doc """
  Transfers ownership to another member (makes them admin, optionally demotes current).
  """
  def transfer_admin(%Collective{} = collective, from_user, to_user) do
    Repo.transaction(fn ->
      # Make new user admin
      case update_member_role(collective, to_user, "admin") do
        {:ok, _} ->
          # Update collective creator
          collective
          |> Ecto.Changeset.change(creator_id: to_user.id)
          |> Repo.update!()

          # Demote old admin to member (optional, they stay admin too)
          update_member_role(collective, from_user, "member")

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  # ============================================
  # HELPERS
  # ============================================

  defp maybe_filter_by_member(query, nil), do: query
  defp maybe_filter_by_member(query, user_id) do
    query
    |> join(:inner, [c], m in CollectiveMembership, on: m.collective_id == c.id)
    |> where([c, m], m.user_id == ^user_id)
  end

  defp maybe_filter_accepting(query, nil), do: query
  defp maybe_filter_accepting(query, true) do
    where(query, [c], c.is_accepting_commissions == true)
  end
  defp maybe_filter_accepting(query, false) do
    where(query, [c], c.is_accepting_commissions == false)
  end

  # ============================================
  # INVITATIONS
  # ============================================

  @doc """
  Creates an invitation for a user to join a collective.
  """
  def create_invitation(collective, inviter, invitee, message \\ nil) do
    # Check if already a member
    if is_member?(collective.id, invitee.id) do
      {:error, :already_member}
    else
      # Check if there's already a pending invitation
      case get_pending_invitation(collective.id, invitee.id) do
        nil ->
          %CollectiveInvitation{}
          |> CollectiveInvitation.changeset(%{
            collective_id: collective.id,
            inviter_id: inviter.id,
            invitee_id: invitee.id,
            message: message,
            expires_at: CollectiveInvitation.default_expiration()
          })
          |> Repo.insert()

        _existing ->
          {:error, :invitation_exists}
      end
    end
  end

  @doc """
  Gets a pending invitation for a specific collective and user.
  """
  def get_pending_invitation(collective_id, invitee_id) do
    CollectiveInvitation
    |> where([i], i.collective_id == ^collective_id and i.invitee_id == ^invitee_id and i.status == "pending")
    |> where([i], i.expires_at > ^DateTime.utc_now())
    |> preload([:collective, :inviter, :invitee])
    |> Repo.one()
  end

  @doc """
  Gets an invitation by ID.
  """
  def get_invitation(id) do
    CollectiveInvitation
    |> Repo.get(id)
    |> Repo.preload([:collective, :inviter, :invitee])
  end

  @doc """
  Lists pending invitations for a user (invitations they've received).
  """
  def list_pending_invitations_for_user(user_id) do
    CollectiveInvitation
    |> where([i], i.invitee_id == ^user_id and i.status == "pending")
    |> where([i], i.expires_at > ^DateTime.utc_now())
    |> preload([collective: [:creator, memberships: :user], inviter: []])
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists pending invitations for a collective (sent by admins).
  """
  def list_pending_invitations_for_collective(collective_id) do
    CollectiveInvitation
    |> where([i], i.collective_id == ^collective_id and i.status == "pending")
    |> where([i], i.expires_at > ^DateTime.utc_now())
    |> preload([:inviter, :invitee])
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
  end

  @doc """
  Accepts an invitation - creates membership and updates invitation status.
  """
  def accept_invitation(%CollectiveInvitation{} = invitation, response_message \\ nil) do
    if CollectiveInvitation.expired?(invitation) do
      {:error, :invitation_expired}
    else
      Repo.transaction(fn ->
        # Update invitation status
        {:ok, updated_invitation} =
          invitation
          |> CollectiveInvitation.response_changeset(%{
            status: "accepted",
            response_message: response_message,
            responded_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })
          |> Repo.update()

        # Create membership
        collective = get_collective(invitation.collective_id)
        invitee = ScriptVoice.Accounts.get_user(invitation.invitee_id)
        {:ok, _membership} = add_member(collective, invitee, "member")

        updated_invitation
      end)
    end
  end

  @doc """
  Declines an invitation.
  """
  def decline_invitation(%CollectiveInvitation{} = invitation, response_message \\ nil) do
    invitation
    |> CollectiveInvitation.response_changeset(%{
      status: "declined",
      response_message: response_message,
      responded_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  @doc """
  Cancels (deletes) an invitation.
  """
  def cancel_invitation(%CollectiveInvitation{} = invitation) do
    Repo.delete(invitation)
  end

  # ============================================
  # JOIN REQUESTS
  # ============================================

  @doc """
  Creates a join request for a user to join a collective.
  """
  def create_join_request(collective, user, message \\ nil) do
    # Check if already a member
    if is_member?(collective.id, user.id) do
      {:error, :already_member}
    else
      # Check if there's already a pending request
      case get_pending_join_request(collective.id, user.id) do
        nil ->
          %CollectiveJoinRequest{}
          |> CollectiveJoinRequest.changeset(%{
            collective_id: collective.id,
            user_id: user.id,
            message: message
          })
          |> Repo.insert()

        _existing ->
          {:error, :request_exists}
      end
    end
  end

  @doc """
  Gets a pending join request for a specific collective and user.
  """
  def get_pending_join_request(collective_id, user_id) do
    CollectiveJoinRequest
    |> where([r], r.collective_id == ^collective_id and r.user_id == ^user_id and r.status == "pending")
    |> preload([:collective, :user])
    |> Repo.one()
  end

  @doc """
  Gets the most recent join request for a user and collective, including rejected ones.
  Useful for showing "your request was declined" status.
  """
  def get_latest_join_request(collective_id, user_id) do
    CollectiveJoinRequest
    |> where([r], r.collective_id == ^collective_id and r.user_id == ^user_id)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> preload([:collective, :user, :reviewed_by])
    |> Repo.one()
  end

  @doc """
  Gets a join request by ID.
  """
  def get_join_request(id) do
    CollectiveJoinRequest
    |> Repo.get(id)
    |> Repo.preload([:collective, :user, :reviewed_by])
  end

  @doc """
  Lists pending join requests for a collective (for admins to review).
  """
  def list_pending_join_requests_for_collective(collective_id) do
    CollectiveJoinRequest
    |> where([r], r.collective_id == ^collective_id and r.status == "pending")
    |> preload(:user)
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists join requests made by a user.
  """
  def list_join_requests_for_user(user_id) do
    CollectiveJoinRequest
    |> where([r], r.user_id == ^user_id)
    |> preload(collective: [:creator, memberships: :user])
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists pending join requests made by a user.
  """
  def list_pending_join_requests_for_user(user_id) do
    CollectiveJoinRequest
    |> where([r], r.user_id == ^user_id and r.status == "pending")
    |> preload(collective: [:creator, memberships: :user])
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists recently rejected join requests made by a user (within last 30 days).
  Returns a map of collective_id => request for easy lookup.
  """
  def list_recent_rejected_requests_for_user(user_id) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    CollectiveJoinRequest
    |> where([r], r.user_id == ^user_id and r.status == "rejected")
    |> where([r], r.reviewed_at >= ^thirty_days_ago)
    |> preload([:collective])
    |> order_by([r], desc: r.reviewed_at)
    |> Repo.all()
    |> Enum.reduce(%{}, fn request, acc ->
      # Only keep the most recent rejection per collective
      Map.put_new(acc, request.collective_id, request)
    end)
  end

  @doc """
  Approves a join request - creates membership and updates request status.
  """
  def approve_join_request(%CollectiveJoinRequest{} = request, reviewer, response_message \\ nil) do
    Repo.transaction(fn ->
      # Update request status
      {:ok, updated_request} =
        request
        |> CollectiveJoinRequest.review_changeset(%{
          status: "approved",
          reviewed_by_id: reviewer.id,
          response_message: response_message,
          reviewed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.update()

      # Create membership
      collective = get_collective(request.collective_id)
      user = ScriptVoice.Accounts.get_user(request.user_id)
      {:ok, _membership} = add_member(collective, user, "member")

      updated_request
    end)
  end

  @doc """
  Rejects a join request.
  """
  def reject_join_request(%CollectiveJoinRequest{} = request, reviewer, response_message \\ nil) do
    request
    |> CollectiveJoinRequest.review_changeset(%{
      status: "rejected",
      reviewed_by_id: reviewer.id,
      response_message: response_message,
      reviewed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  @doc """
  Adds an admin note/message to a pending join request.
  """
  def add_note_to_join_request(%CollectiveJoinRequest{} = request, note) do
    request
    |> CollectiveJoinRequest.note_changeset(%{response_message: note})
    |> Repo.update()
  end

  @doc """
  Cancels (deletes) a join request.
  """
  def cancel_join_request(%CollectiveJoinRequest{} = request) do
    Repo.delete(request)
  end

  # ============================================
  # USER MEMBERSHIP QUERIES
  # ============================================

  @doc """
  Gets all membership info for a user including role.
  """
  def list_memberships_for_user(user_id) do
    CollectiveMembership
    |> where([m], m.user_id == ^user_id)
    |> preload(collective: [:creator, memberships: :user])
    |> order_by([m], desc: m.joined_at)
    |> Repo.all()
  end

  @doc """
  Gets membership with role for display.
  """
  def get_user_membership_role(collective_id, user_id) do
    CollectiveMembership
    |> where([m], m.collective_id == ^collective_id and m.user_id == ^user_id)
    |> select([m], m.role)
    |> Repo.one()
  end

  @doc """
  Allows a member to leave a collective.
  Returns error if they're the last admin.
  """
  def leave_collective(collective_id, user_id) do
    membership = get_membership(collective_id, user_id)

    cond do
      is_nil(membership) ->
        {:error, :not_member}

      membership.role == "admin" && admin_count(collective_id) <= 1 ->
        {:error, :last_admin}

      true ->
        Repo.delete(membership)
    end
  end

  # ============================================
  # JOIN REQUEST MESSAGES
  # ============================================

  @doc """
  Creates a message in a join request conversation.
  """
  def create_join_request_message(join_request_id, sender_id, content) do
    %JoinRequestMessage{}
    |> JoinRequestMessage.changeset(%{
      join_request_id: join_request_id,
      sender_id: sender_id,
      content: content
    })
    |> Repo.insert()
  end

  @doc """
  Lists all messages for a join request, ordered by creation time.
  """
  def list_join_request_messages(join_request_id) do
    JoinRequestMessage
    |> where([m], m.join_request_id == ^join_request_id)
    |> order_by([m], asc: m.inserted_at)
    |> preload(:sender)
    |> Repo.all()
  end

  @doc """
  Gets a join request with its messages preloaded.
  """
  def get_join_request_with_messages(id) do
    CollectiveJoinRequest
    |> Repo.get(id)
    |> Repo.preload([:collective, :user, :reviewed_by, messages: :sender])
  end

  @doc """
  Gets a pending join request with messages for a specific collective and user.
  """
  def get_pending_join_request_with_messages(collective_id, user_id) do
    CollectiveJoinRequest
    |> where([r], r.collective_id == ^collective_id and r.user_id == ^user_id and r.status == "pending")
    |> preload([:collective, :user, messages: :sender])
    |> Repo.one()
  end

  @doc """
  Gets the latest join request with messages for a specific collective and user.
  """
  def get_latest_join_request_with_messages(collective_id, user_id) do
    CollectiveJoinRequest
    |> where([r], r.collective_id == ^collective_id and r.user_id == ^user_id)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> preload([:collective, :user, :reviewed_by, messages: :sender])
    |> Repo.one()
  end

  @doc """
  Lists pending join requests for a collective with messages.
  """
  def list_pending_join_requests_with_messages(collective_id) do
    CollectiveJoinRequest
    |> where([r], r.collective_id == ^collective_id and r.status == "pending")
    |> preload([:user, messages: :sender])
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists pending join requests made by a user with messages.
  """
  def list_pending_join_requests_for_user_with_messages(user_id) do
    CollectiveJoinRequest
    |> where([r], r.user_id == ^user_id and r.status == "pending")
    |> preload([collective: [:creator, memberships: :user], messages: :sender])
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end
end
