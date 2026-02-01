defmodule ScriptVoice.Notifications do
  @moduledoc """
  The Notifications context - handles creating, reading, and managing user notifications.
  Uses Phoenix PubSub for real-time delivery.
  """

  import Ecto.Query, warn: false
  alias ScriptVoice.Repo
  alias ScriptVoice.Notifications.Notification

  @pubsub ScriptVoice.PubSub

  # =============================================================================
  # Creating Notifications
  # =============================================================================

  @doc """
  Creates a notification and broadcasts it via PubSub.
  """
  def create_notification(user_id, type, title, body \\ nil, opts \\ []) do
    related_type = Keyword.get(opts, :related_type)
    related_id = Keyword.get(opts, :related_id)
    action_url = Keyword.get(opts, :action_url)

    attrs = %{
      user_id: user_id,
      type: type,
      title: title,
      body: body,
      related_type: related_type,
      related_id: related_id,
      action_url: action_url
    }

    with {:ok, notification} <- insert_notification(attrs) do
      broadcast_notification(user_id, notification)
      {:ok, notification}
    end
  end

  defp insert_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  # =============================================================================
  # Commission Notification Helpers
  # =============================================================================

  @doc """
  Notifies a performer of a new commission request.
  """
  def notify_commission_request_received(performer_id, writer_name, screenplay_title, commission_id) do
    create_notification(
      performer_id,
      "commission_request_received",
      "New commission request from #{writer_name}",
      "#{writer_name} wants you to perform \"#{screenplay_title}\"",
      related_type: "commission_request",
      related_id: commission_id,
      action_url: "/commissions/#{commission_id}"
    )
  end

  @doc """
  Notifies a writer that their commission was accepted.
  """
  def notify_commission_accepted(writer_id, performer_name, screenplay_title, commission_id) do
    create_notification(
      writer_id,
      "commission_accepted",
      "#{performer_name} accepted your commission",
      "Your commission for \"#{screenplay_title}\" has been accepted!",
      related_type: "commission_request",
      related_id: commission_id,
      action_url: "/commissions/#{commission_id}"
    )
  end

  @doc """
  Notifies a writer that their commission was declined.
  """
  def notify_commission_declined(writer_id, performer_name, screenplay_title, commission_id) do
    create_notification(
      writer_id,
      "commission_declined",
      "Commission request declined",
      "#{performer_name} has declined your commission for \"#{screenplay_title}\"",
      related_type: "commission_request",
      related_id: commission_id,
      action_url: "/commissions/#{commission_id}"
    )
  end

  @doc """
  Notifies a writer that audio has been submitted.
  """
  def notify_submission_received(writer_id, performer_name, screenplay_title, commission_id) do
    create_notification(
      writer_id,
      "submission_received",
      "Audio submitted for \"#{screenplay_title}\"",
      "#{performer_name} has submitted audio for your review",
      related_type: "commission_request",
      related_id: commission_id,
      action_url: "/commissions/#{commission_id}"
    )
  end

  @doc """
  Notifies a performer that revision is requested.
  """
  def notify_revision_requested(performer_id, writer_name, screenplay_title, commission_id) do
    create_notification(
      performer_id,
      "revision_requested",
      "Revision requested for \"#{screenplay_title}\"",
      "#{writer_name} has requested changes",
      related_type: "commission_request",
      related_id: commission_id,
      action_url: "/commissions/#{commission_id}"
    )
  end

  @doc """
  Notifies both parties that commission is completed.
  """
  def notify_commission_completed(user_id, other_party_name, screenplay_title, commission_id) do
    create_notification(
      user_id,
      "commission_completed",
      "Commission completed!",
      "The commission for \"#{screenplay_title}\" with #{other_party_name} is complete",
      related_type: "commission_request",
      related_id: commission_id,
      action_url: "/commissions/#{commission_id}"
    )
  end

  @doc """
  Notifies a user that commission was cancelled.
  """
  def notify_commission_cancelled(user_id, other_party_name, screenplay_title, commission_id) do
    create_notification(
      user_id,
      "commission_cancelled",
      "Commission cancelled",
      "The commission for \"#{screenplay_title}\" has been cancelled",
      related_type: "commission_request",
      related_id: commission_id,
      action_url: "/commissions/#{commission_id}"
    )
  end

  @doc """
  Notifies a user of a new message.
  """
  def notify_message_received(user_id, sender_name, commission_id) do
    create_notification(
      user_id,
      "message_received",
      "New message from #{sender_name}",
      nil,
      related_type: "commission_request",
      related_id: commission_id,
      action_url: "/commissions/#{commission_id}"
    )
  end

  @doc """
  Notifies a performer that payment was released.
  """
  def notify_payment_released(performer_id, amount_cents, commission_id) do
    amount = "$#{:erlang.float_to_binary(amount_cents / 100, decimals: 2)}"

    create_notification(
      performer_id,
      "payment_released",
      "Payment received: #{amount}",
      "Your earnings have been released to your account",
      related_type: "commission_request",
      related_id: commission_id,
      action_url: "/commissions/#{commission_id}"
    )
  end

  # =============================================================================
  # Reading Notifications
  # =============================================================================

  @doc """
  Lists notifications for a user.
  """
  def list_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    unread_only = Keyword.get(opts, :unread_only, false)

    Notification
    |> where([n], n.user_id == ^user_id)
    |> maybe_filter_unread(unread_only)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_filter_unread(query, false), do: query
  defp maybe_filter_unread(query, true) do
    where(query, [n], is_nil(n.read_at))
  end

  @doc """
  Gets the count of unread notifications for a user.
  """
  def get_unread_count(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id)
    |> where([n], is_nil(n.read_at))
    |> Repo.aggregate(:count)
  end

  @doc """
  Marks a single notification as read.
  """
  def mark_read(notification_id) do
    notification = Repo.get!(Notification, notification_id)

    notification
    |> Notification.mark_read_changeset()
    |> Repo.update()
  end

  @doc """
  Marks all notifications as read for a user.
  """
  def mark_all_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(n in Notification,
      where: n.user_id == ^user_id,
      where: is_nil(n.read_at)
    )
    |> Repo.update_all(set: [read_at: now])
  end

  # =============================================================================
  # PubSub
  # =============================================================================

  @doc """
  Subscribes to notifications for a user.
  Call this in LiveView mount to receive real-time notifications.
  """
  def subscribe_to_notifications(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, notifications_topic(user_id))
  end

  @doc """
  Unsubscribes from notifications for a user.
  """
  def unsubscribe_from_notifications(user_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, notifications_topic(user_id))
  end

  defp broadcast_notification(user_id, notification) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      notifications_topic(user_id),
      {:new_notification, notification}
    )
  end

  defp notifications_topic(user_id), do: "notifications:#{user_id}"
end
