defmodule ScriptVoiceWeb.CommissionDetailLive do
  @moduledoc """
  LiveView for viewing and managing a single commission.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Commissions
  alias ScriptVoice.Notifications
  alias ScriptVoiceWeb.CommissionSubmitAudioComponent

  @impl true
  def mount(%{"id" => id}, session, socket) do
    current_user = get_current_user(session)

    case current_user do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Please sign in to view this commission")
         |> push_navigate(to: ~p"/verify?type=visitor")}

      user ->
        commission = Commissions.get_commission_request(id)

        cond do
          is_nil(commission) ->
            {:ok,
             socket
             |> put_flash(:error, "Commission not found")
             |> push_navigate(to: ~p"/commissions")}

          commission.writer_id != user.id and commission.performer_id != user.id ->
            {:ok,
             socket
             |> put_flash(:error, "You don't have access to this commission")
             |> push_navigate(to: ~p"/commissions")}

          true ->
            # Subscribe to notifications
            if connected?(socket) do
              Notifications.subscribe_to_notifications(user.id)
            end

            role = if commission.writer_id == user.id, do: "writer", else: "performer"
            messages = Commissions.list_messages(id)
            submissions = Commissions.get_submissions_for_commission(id)

            # Mark messages as read
            Commissions.mark_messages_read(id, user.id)

            {:ok,
             socket
             |> assign(:current_user, user)
             |> assign(:commission, commission)
             |> assign(:role, role)
             |> assign(:messages, messages)
             |> assign(:submissions, submissions)
             |> assign(:message_input, "")
             |> assign(:feedback_input, "")
             |> assign(:show_feedback_form, false)
             |> assign(:page_title, commission.screenplay.title)}
        end
    end
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> ScriptVoice.Accounts.get_user(user_id)
    end
  end

  @impl true
  def handle_event("accept", _params, socket) do
    commission = socket.assigns.commission

    case Commissions.accept_commission(commission.id, socket.assigns.current_user.id) do
      {:ok, updated} ->
        # Notify writer
        Notifications.notify_commission_accepted(
          commission.writer_id,
          socket.assigns.current_user.name,
          commission.screenplay.title,
          commission.id
        )

        {:noreply,
         socket
         |> assign(:commission, Commissions.get_commission_request(updated.id))
         |> put_flash(:info, "Commission accepted!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to accept commission")}
    end
  end

  @impl true
  def handle_event("decline", %{"reason" => reason}, socket) do
    commission = socket.assigns.commission

    case Commissions.decline_commission(commission.id, socket.assigns.current_user.id, reason) do
      {:ok, updated} ->
        # Notify writer
        Notifications.notify_commission_declined(
          commission.writer_id,
          socket.assigns.current_user.name,
          commission.screenplay.title,
          commission.id
        )

        {:noreply,
         socket
         |> assign(:commission, Commissions.get_commission_request(updated.id))
         |> put_flash(:info, "Commission declined")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to decline commission")}
    end
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when byte_size(message) > 0 do
    case Commissions.send_message(
           socket.assigns.commission.id,
           socket.assigns.current_user.id,
           message
         ) do
      {:ok, _msg} ->
        # Notify other party
        other_id = get_other_party_id(socket.assigns.commission, socket.assigns.role)
        Notifications.notify_message_received(
          other_id,
          socket.assigns.current_user.name,
          socket.assigns.commission.id
        )

        messages = Commissions.list_messages(socket.assigns.commission.id)

        {:noreply,
         socket
         |> assign(:messages, messages)
         |> assign(:message_input, "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_message_input", %{"message" => message}, socket) do
    {:noreply, assign(socket, :message_input, message)}
  end

  @impl true
  def handle_event("show_feedback_form", _params, socket) do
    {:noreply, assign(socket, :show_feedback_form, true)}
  end

  @impl true
  def handle_event("hide_feedback_form", _params, socket) do
    {:noreply, assign(socket, :show_feedback_form, false)}
  end

  @impl true
  def handle_event("update_feedback", %{"feedback" => feedback}, socket) do
    {:noreply, assign(socket, :feedback_input, feedback)}
  end

  @impl true
  def handle_event("request_revision", %{"submission_id" => submission_id}, socket) do
    feedback = socket.assigns.feedback_input

    case Commissions.request_revision(submission_id, socket.assigns.current_user.id, feedback) do
      {:ok, _} ->
        commission = Commissions.get_commission_request(socket.assigns.commission.id)

        # Notify performer
        Notifications.notify_revision_requested(
          commission.performer_id,
          socket.assigns.current_user.name,
          commission.screenplay.title,
          commission.id
        )

        {:noreply,
         socket
         |> assign(:commission, commission)
         |> assign(:submissions, Commissions.get_submissions_for_commission(commission.id))
         |> assign(:feedback_input, "")
         |> assign(:show_feedback_form, false)
         |> put_flash(:info, "Revision requested")}

      {:error, :no_retakes_remaining} ->
        {:noreply, put_flash(socket, :error, "No retakes remaining")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to request revision")}
    end
  end

  @impl true
  def handle_event("approve_submission", %{"submission_id" => submission_id}, socket) do
    case Commissions.approve_submission(submission_id, socket.assigns.current_user.id) do
      {:ok, commission} ->
        commission = Commissions.get_commission_request(commission.id)

        # Notify performer
        Notifications.notify_commission_completed(
          commission.performer_id,
          socket.assigns.current_user.name,
          commission.screenplay.title,
          commission.id
        )

        {:noreply,
         socket
         |> assign(:commission, commission)
         |> assign(:submissions, Commissions.get_submissions_for_commission(commission.id))
         |> put_flash(:info, "Submission approved! Commission completed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to approve submission")}
    end
  end

  @impl true
  def handle_info({:new_notification, _notification}, socket) do
    # Reload data when notification received
    commission = Commissions.get_commission_request(socket.assigns.commission.id)
    messages = Commissions.list_messages(socket.assigns.commission.id)
    submissions = Commissions.get_submissions_for_commission(socket.assigns.commission.id)

    {:noreply,
     socket
     |> assign(:commission, commission)
     |> assign(:messages, messages)
     |> assign(:submissions, submissions)}
  end

  @impl true
  def handle_info({:submit_commission_audio, audio_data}, socket) do
    commission = socket.assigns.commission

    # Submit the audio to the commission
    case Commissions.submit_audio(commission.id, socket.assigns.current_user.id, audio_data) do
      {:ok, _submission} ->
        # Notify writer of new submission
        Notifications.notify_submission_received(
          commission.writer_id,
          socket.assigns.current_user.name,
          commission.screenplay.title,
          commission.id
        )

        # Reload data
        updated_commission = Commissions.get_commission_request(commission.id)
        submissions = Commissions.get_submissions_for_commission(commission.id)

        {:noreply,
         socket
         |> assign(:commission, updated_commission)
         |> assign(:submissions, submissions)
         |> put_flash(:info, "Recording submitted successfully!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to submit recording: #{inspect(reason)}")}
    end
  end

  defp get_other_party_id(commission, "writer"), do: commission.performer_id
  defp get_other_party_id(commission, "performer"), do: commission.writer_id

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-4xl mx-auto">
        <!-- Back Link -->
        <.link navigate={~p"/commissions"} class="text-sm text-emerald-600 hover:underline mb-4 inline-block">
          &larr; Back to Commissions
        </.link>

        <!-- Commission Header -->
        <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
            <div>
              <h1 class="text-xl sm:text-2xl font-bold">
                <%= @commission.screenplay.title %>
              </h1>
              <p class="text-gray-500 mt-1">
                <%= if @role == "writer" do %>
                  Performer: <.link navigate={~p"/profile/#{@commission.performer_id}"} class="text-emerald-600 hover:underline"><%= @commission.performer.name %></.link>
                <% else %>
                  Writer: <.link navigate={~p"/profile/#{@commission.writer_id}"} class="text-emerald-600 hover:underline"><%= @commission.writer.name %></.link>
                <% end %>
              </p>
              <!-- Screenplay Links -->
              <div class="mt-3 flex flex-wrap gap-2">
                <!-- View Screenplay Details -->
                <.link
                  navigate={~p"/screenplay/#{@commission.screenplay.id}?from=commission&commission_id=#{@commission.id}"}
                  class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-50 text-emerald-700 rounded-lg font-medium hover:bg-emerald-100 transition"
                >
                  <.icon name="hero-information-circle" class="w-4 h-4" />
                  Screenplay Details
                </.link>
                <!-- View Script -->
                <%= cond do %>
                  <% @commission.screenplay.script_content && String.length(@commission.screenplay.script_content) > 0 -> %>
                    <.link
                      navigate={~p"/screenplay/#{@commission.screenplay.id}/read?from=commission&commission_id=#{@commission.id}"}
                      class="inline-flex items-center gap-2 px-4 py-2 bg-blue-50 text-blue-700 rounded-lg font-medium hover:bg-blue-100 transition"
                    >
                      <.icon name="hero-document-text" class="w-4 h-4" />
                      Read Script
                    </.link>
                  <% @commission.screenplay.pdf_url -> %>
                    <a
                      href={@commission.screenplay.pdf_url}
                      target="_blank"
                      class="inline-flex items-center gap-2 px-4 py-2 bg-blue-50 text-blue-700 rounded-lg font-medium hover:bg-blue-100 transition"
                    >
                      <.icon name="hero-document-text" class="w-4 h-4" />
                      Read Script (PDF)
                    </a>
                  <% true -> %>
                <% end %>
              </div>
            </div>
            <div class="text-right">
              <.status_badge status={@commission.status} />
              <p class="text-lg font-semibold text-emerald-600 mt-2">
                <%= format_amount(@commission.agreed_amount_cents || @commission.offered_amount_cents) %>
              </p>
            </div>
          </div>

          <!-- Commission Details -->
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-6 pt-6 border-t">
            <div>
              <p class="text-xs text-gray-500">Created</p>
              <p class="font-medium"><%= format_date(@commission.inserted_at) %></p>
            </div>
            <%= if @commission.deadline do %>
              <div>
                <p class="text-xs text-gray-500">Deadline</p>
                <p class="font-medium"><%= format_date(@commission.deadline) %></p>
              </div>
            <% end %>
            <div>
              <p class="text-xs text-gray-500">Retakes</p>
              <p class="font-medium"><%= @commission.retakes_used %> / <%= @commission.retakes_included %> used</p>
            </div>
            <%= if @commission.is_rush do %>
              <div>
                <span class="text-xs bg-orange-100 text-orange-700 px-2 py-1 rounded-full">Rush Job</span>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Action Buttons for Performer (Pending) -->
        <%= if @role == "performer" and @commission.status == "pending" do %>
          <div class="bg-yellow-50 border border-yellow-200 rounded-xl p-4 sm:p-6 mb-6">
            <h2 class="font-semibold mb-2">Commission Request</h2>
            <p class="text-gray-600 mb-4"><%= @commission.writer_message %></p>

            <div class="flex flex-col sm:flex-row gap-3">
              <button
                phx-click="accept"
                class="bg-emerald-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-emerald-700"
              >
                Accept Commission
              </button>
              <button
                phx-click="decline"
                phx-value-reason="Not available"
                class="bg-white border border-gray-300 text-gray-700 px-6 py-2 rounded-lg font-medium hover:bg-gray-50"
              >
                Decline
              </button>
            </div>
          </div>
        <% end %>

        <!-- Submit Audio Section (for performers with active commissions) -->
        <%= if @role == "performer" and @commission.status in ["accepted", "in_progress", "revision_requested"] do %>
          <div class="mb-6">
            <.live_component
              module={CommissionSubmitAudioComponent}
              id="commission-submit-audio"
              commission={@commission}
              current_user={@current_user}
            />
          </div>
        <% end %>

        <!-- Submissions Section -->
        <%= if @submissions != [] or @commission.status in ["accepted", "in_progress", "revision_requested"] do %>
          <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
            <h2 class="font-semibold mb-4">Submissions</h2>

            <%= if @submissions == [] do %>
              <p class="text-gray-500 text-sm">No submissions yet</p>
            <% else %>
              <div class="space-y-4">
                <%= for submission <- Enum.reverse(@submissions) do %>
                  <div class={"border rounded-lg p-4 " <> submission_bg(submission.status)}>
                    <div class="flex items-center justify-between mb-2">
                      <div class="flex items-center gap-2">
                        <span class="font-medium">Submission #<%= submission.submission_number %></span>
                        <.submission_badge status={submission.status} />
                      </div>
                      <span class="text-xs text-gray-500">
                        <%= format_datetime(submission.inserted_at) %>
                      </span>
                    </div>

                    <!-- Audio Player -->
                    <audio controls class="w-full mb-2">
                      <source src={submission.audio_url} type="audio/mpeg" />
                      Your browser does not support the audio element.
                    </audio>

                    <%= if submission.performer_notes do %>
                      <p class="text-sm text-gray-600 mt-2">
                        <span class="font-medium">Notes:</span> <%= submission.performer_notes %>
                      </p>
                    <% end %>

                    <%= if submission.writer_feedback do %>
                      <p class="text-sm text-orange-600 mt-2 bg-orange-50 p-2 rounded">
                        <span class="font-medium">Feedback:</span> <%= submission.writer_feedback %>
                      </p>
                    <% end %>

                    <!-- Writer Actions for Latest Pending Submission -->
                    <%= if @role == "writer" and submission.status == "pending_review" do %>
                      <div class="mt-4 pt-4 border-t">
                        <%= if @show_feedback_form do %>
                          <div class="space-y-3">
                            <textarea
                              phx-change="update_feedback"
                              name="feedback"
                              rows="3"
                              placeholder="Provide feedback for the revision..."
                              class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500"
                            ><%= @feedback_input %></textarea>
                            <div class="flex gap-2">
                              <button
                                phx-click="request_revision"
                                phx-value-submission_id={submission.id}
                                class="bg-orange-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-orange-700"
                                disabled={@commission.retakes_used >= @commission.retakes_included}
                              >
                                Request Revision (<%= @commission.retakes_included - @commission.retakes_used %> left)
                              </button>
                              <button
                                phx-click="hide_feedback_form"
                                class="text-gray-600 px-4 py-2 text-sm"
                              >
                                Cancel
                              </button>
                            </div>
                          </div>
                        <% else %>
                          <div class="flex gap-3">
                            <button
                              phx-click="approve_submission"
                              phx-value-submission_id={submission.id}
                              class="bg-emerald-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-emerald-700"
                            >
                              Approve & Complete
                            </button>
                            <%= if @commission.retakes_used < @commission.retakes_included do %>
                              <button
                                phx-click="show_feedback_form"
                                class="bg-white border border-orange-300 text-orange-600 px-4 py-2 rounded-lg text-sm font-medium hover:bg-orange-50"
                              >
                                Request Revision
                              </button>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Messages Section -->
        <div class="bg-white border rounded-xl p-4 sm:p-6">
          <h2 class="font-semibold mb-4">Messages</h2>

          <!-- Message List -->
          <div class="space-y-4 mb-4 max-h-96 overflow-y-auto">
            <%= if @commission.writer_message do %>
              <div class="flex gap-3">
                <div class="w-8 h-8 bg-emerald-100 rounded-full flex items-center justify-center flex-shrink-0">
                  <span class="text-sm font-medium text-emerald-600">
                    <%= String.first(@commission.writer.name) %>
                  </span>
                </div>
                <div class="flex-1">
                  <p class="text-sm font-medium"><%= @commission.writer.name %> <span class="text-gray-400 font-normal">(initial request)</span></p>
                  <p class="text-gray-600 mt-1"><%= @commission.writer_message %></p>
                </div>
              </div>
            <% end %>

            <%= if @commission.performer_response do %>
              <div class="flex gap-3">
                <div class="w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center flex-shrink-0">
                  <span class="text-sm font-medium text-purple-600">
                    <%= String.first(@commission.performer.name) %>
                  </span>
                </div>
                <div class="flex-1">
                  <p class="text-sm font-medium"><%= @commission.performer.name %> <span class="text-gray-400 font-normal">(response)</span></p>
                  <p class="text-gray-600 mt-1"><%= @commission.performer_response %></p>
                </div>
              </div>
            <% end %>

            <%= for message <- @messages do %>
              <div class="flex gap-3">
                <div class={"w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 " <>
                  if message.sender_id == @commission.writer_id, do: "bg-emerald-100", else: "bg-purple-100"}>
                  <span class={"text-sm font-medium " <>
                    if message.sender_id == @commission.writer_id, do: "text-emerald-600", else: "text-purple-600"}>
                    <%= String.first(message.sender.name) %>
                  </span>
                </div>
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <p class="text-sm font-medium"><%= message.sender.name %></p>
                    <span class="text-xs text-gray-400"><%= format_datetime(message.inserted_at) %></span>
                  </div>
                  <p class="text-gray-600 mt-1"><%= message.message %></p>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Message Input -->
          <%= if @commission.status not in ["completed", "cancelled", "declined"] do %>
            <form phx-submit="send_message" class="flex gap-2">
              <input
                type="text"
                name="message"
                value={@message_input}
                phx-change="update_message_input"
                placeholder="Type a message..."
                class="flex-1 px-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
              <button
                type="submit"
                class="bg-emerald-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-emerald-700"
              >
                Send
              </button>
            </form>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge(assigns) do
    {bg_color, text_color, label} = status_styles(assigns.status)
    assigns = assign(assigns, :bg_color, bg_color)
    assigns = assign(assigns, :text_color, text_color)
    assigns = assign(assigns, :label, label)

    ~H"""
    <span class={"text-xs px-2 py-1 rounded-full #{@bg_color} #{@text_color}"}>
      <%= @label %>
    </span>
    """
  end

  defp submission_badge(assigns) do
    {bg_color, text_color, label} = submission_status_styles(assigns.status)
    assigns = assign(assigns, :bg_color, bg_color)
    assigns = assign(assigns, :text_color, text_color)
    assigns = assign(assigns, :label, label)

    ~H"""
    <span class={"text-xs px-2 py-0.5 rounded #{@bg_color} #{@text_color}"}>
      <%= @label %>
    </span>
    """
  end

  defp status_styles("pending"), do: {"bg-yellow-100", "text-yellow-700", "Pending"}
  defp status_styles("accepted"), do: {"bg-blue-100", "text-blue-700", "Accepted"}
  defp status_styles("in_progress"), do: {"bg-blue-100", "text-blue-700", "In Progress"}
  defp status_styles("submitted"), do: {"bg-purple-100", "text-purple-700", "Submitted"}
  defp status_styles("revision_requested"), do: {"bg-orange-100", "text-orange-700", "Revision Requested"}
  defp status_styles("completed"), do: {"bg-emerald-100", "text-emerald-700", "Completed"}
  defp status_styles("cancelled"), do: {"bg-gray-100", "text-gray-700", "Cancelled"}
  defp status_styles("declined"), do: {"bg-red-100", "text-red-700", "Declined"}
  defp status_styles("disputed"), do: {"bg-red-100", "text-red-700", "Disputed"}
  defp status_styles(_), do: {"bg-gray-100", "text-gray-700", "Unknown"}

  defp submission_status_styles("pending_review"), do: {"bg-purple-100", "text-purple-700", "Pending Review"}
  defp submission_status_styles("approved"), do: {"bg-emerald-100", "text-emerald-700", "Approved"}
  defp submission_status_styles("revision_requested"), do: {"bg-orange-100", "text-orange-700", "Revision Requested"}
  defp submission_status_styles(_), do: {"bg-gray-100", "text-gray-700", "Unknown"}

  defp submission_bg("pending_review"), do: "bg-purple-50"
  defp submission_bg("approved"), do: "bg-emerald-50"
  defp submission_bg("revision_requested"), do: "bg-orange-50"
  defp submission_bg(_), do: ""

  defp format_amount(nil), do: "-"
  defp format_amount(cents), do: "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"

  defp format_date(date) when is_struct(date, Date) do
    Calendar.strftime(date, "%b %d, %Y")
  end
  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %H:%M")
  end
end
