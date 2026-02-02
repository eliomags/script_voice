defmodule ScriptVoiceWeb.DashboardLive do
  @moduledoc """
  User dashboard - the central hub for users to manage their ScriptVoice activity.
  Tabbed interface with all functionality in one place.
  Mobile-first design.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.{Accounts, Commissions, Notifications, Screenplays, Audio}
  alias ScriptVoice.Audio.AudioVersion
  alias ScriptVoice.Screenplays.{Screenplay, Character}

  @writer_tabs [
    {"overview", "Overview", "hero-home"},
    {"screenplays", "My Scripts", "hero-document-text"},
    {"commissions", "Commissions", "hero-clipboard-document-list"},
    {"profile", "Profile", "hero-user"}
  ]

  @performer_tabs [
    {"overview", "Overview", "hero-home"},
    {"audio", "My Audio", "hero-microphone"},
    {"commissions", "Commissions", "hero-clipboard-document-list"},
    {"profile", "Profile", "hero-user"}
  ]

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    if current_user do
      if connected?(socket) do
        Notifications.subscribe_to_notifications(current_user.id)
      end

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:page_title, "Dashboard")
       |> assign(:active_tab, "overview")
       |> assign(:show_upload_form, false)
       |> assign(:delete_confirm_id, nil)
       |> assign(:edit_screenplay_id, nil)
       |> assign(:edit_title, "")
       |> assign(:edit_genre, "")
       |> assign(:edit_logline, "")
       |> assign_tabs()
       |> load_all_data()}
    else
      {:ok, push_navigate(socket, to: ~p"/demo-login")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = Map.get(params, "tab", "overview")
    valid_tabs = Enum.map(socket.assigns.tabs, fn {id, _, _} -> id end)

    tab = if tab in valid_tabs, do: tab, else: "overview"

    {:noreply, assign(socket, :active_tab, tab)}
  end

  defp assign_tabs(socket) do
    tabs = case socket.assigns.current_user.user_type do
      "writer" -> @writer_tabs
      "voice_artist" -> @performer_tabs
      _ -> [{"overview", "Overview", "hero-home"}, {"profile", "Profile", "hero-user"}]
    end
    assign(socket, :tabs, tabs)
  end

  defp load_all_data(socket) do
    user = socket.assigns.current_user

    socket
    |> load_notifications(user)
    |> load_screenplays(user)
    |> load_audio_versions(user)
    |> load_commissions(user)
    |> load_stats(user)
    |> init_upload_form()
  end

  defp load_notifications(socket, user) do
    notifications = Notifications.list_notifications(user.id, limit: 10)
    unread_count = Notifications.get_unread_count(user.id)

    socket
    |> assign(:notifications, notifications)
    |> assign(:unread_count, unread_count)
  end

  defp load_screenplays(socket, %{user_type: "writer"} = user) do
    screenplays = Screenplays.list_screenplays(writer_id: user.id)
    assign(socket, :screenplays, screenplays)
  end
  defp load_screenplays(socket, _), do: assign(socket, :screenplays, [])

  defp load_audio_versions(socket, %{user_type: "voice_artist"} = user) do
    audio_versions = Audio.list_audio_versions_by_user(user.id)
    assign(socket, :audio_versions, audio_versions)
  end
  defp load_audio_versions(socket, _), do: assign(socket, :audio_versions, [])

  defp load_commissions(socket, user) do
    # Load as both writer and performer
    writer_commissions = Commissions.list_commission_requests_for_writer(user.id)
    performer_commissions = Commissions.list_commission_requests_for_performer(user.id)

    socket
    |> assign(:writer_commissions, writer_commissions)
    |> assign(:performer_commissions, performer_commissions)
    |> assign(:commission_filter, "all")
  end

  defp load_stats(socket, %{user_type: "writer"} = user) do
    stats = Commissions.get_writer_stats(user.id)
    assign(socket, :stats, stats)
  end
  defp load_stats(socket, %{user_type: "voice_artist"} = user) do
    stats = Commissions.get_performer_stats(user.id)

    # Check setup status
    pricing = Commissions.get_performer_pricing(user.id)
    stripe_ready = Commissions.performer_ready_for_payments?(user.id)

    socket
    |> assign(:stats, stats)
    |> assign(:pricing_set, pricing != nil)
    |> assign(:stripe_ready, stripe_ready)
  end
  defp load_stats(socket, _), do: assign(socket, :stats, nil)

  defp init_upload_form(socket) do
    socket
    |> assign(:upload_step, 1)
    |> assign(:upload_title, "")
    |> assign(:upload_genre, "Drama")
    |> assign(:upload_logline, "")
    |> assign(:upload_characters, [])
    |> assign(:upload_error, nil)
    |> allow_upload(:pdf, accept: ~w(.pdf), max_entries: 1, max_file_size: 10_000_000, auto_upload: true)
    |> allow_upload(:replace_pdf, accept: ~w(.pdf), max_entries: 1, max_file_size: 10_000_000, auto_upload: true)
  end

  # ===========================================================================
  # Event Handlers
  # ===========================================================================

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/dashboard?tab=#{tab}")}
  end

  @impl true
  def handle_event("filter_commissions", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :commission_filter, filter)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    Notifications.mark_all_read(socket.assigns.current_user.id)

    notifications =
      Enum.map(socket.assigns.notifications, fn n ->
        %{n | read_at: DateTime.utc_now()}
      end)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, 0)}
  end

  # Upload form events
  @impl true
  def handle_event("toggle_upload_form", _, socket) do
    {:noreply, assign(socket, :show_upload_form, !socket.assigns.show_upload_form)}
  end

  @impl true
  def handle_event("validate_upload", params, socket) do
    socket =
      socket
      |> assign(:upload_error, nil)
      |> then(fn s -> if params["title"], do: assign(s, :upload_title, params["title"]), else: s end)
      |> then(fn s -> if params["genre"], do: assign(s, :upload_genre, params["genre"]), else: s end)
      |> then(fn s -> if params["logline"], do: assign(s, :upload_logline, params["logline"]), else: s end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("continue_to_characters", _, socket) do
    cond do
      socket.assigns.upload_title == "" ->
        {:noreply, assign(socket, :upload_error, "Please enter a title")}

      socket.assigns.upload_logline == "" ->
        {:noreply, assign(socket, :upload_error, "Please enter a logline")}

      true ->
        {:noreply, assign(socket, :upload_step, 2)}
    end
  end

  @impl true
  def handle_event("back_to_step_1", _, socket) do
    {:noreply, assign(socket, :upload_step, 1)}
  end

  @impl true
  def handle_event("add_character", _, socket) do
    new_char = %{
      name: "NEW CHARACTER",
      gender: "Unknown",
      estimated_lines: 0,
      description: ""
    }

    {:noreply, update(socket, :upload_characters, &(&1 ++ [new_char]))}
  end

  @impl true
  def handle_event("update_character", %{"index" => index, "field" => field, "value" => value}, socket) do
    index = String.to_integer(index)

    characters =
      socket.assigns.upload_characters
      |> List.update_at(index, fn char ->
        Map.put(char, String.to_atom(field), value)
      end)

    {:noreply, assign(socket, :upload_characters, characters)}
  end

  @impl true
  def handle_event("remove_character", %{"index" => index}, socket) do
    index = String.to_integer(index)
    characters = List.delete_at(socket.assigns.upload_characters, index)
    {:noreply, assign(socket, :upload_characters, characters)}
  end

  # Edit screenplay
  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    screenplay = Screenplays.get_screenplay!(id)

    if screenplay.writer_id == socket.assigns.current_user.id do
      {:noreply,
       socket
       |> assign(:edit_screenplay_id, id)
       |> assign(:edit_title, screenplay.title)
       |> assign(:edit_genre, screenplay.genre)
       |> assign(:edit_logline, screenplay.logline)}
    else
      {:noreply, put_flash(socket, :error, "You can only edit your own screenplays")}
    end
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply,
     socket
     |> assign(:edit_screenplay_id, nil)
     |> assign(:edit_title, "")
     |> assign(:edit_genre, "")
     |> assign(:edit_logline, "")}
  end

  @impl true
  def handle_event("validate_edit", params, socket) do
    socket =
      socket
      |> then(fn s -> if params["title"], do: assign(s, :edit_title, params["title"]), else: s end)
      |> then(fn s -> if params["genre"], do: assign(s, :edit_genre, params["genre"]), else: s end)
      |> then(fn s -> if params["logline"], do: assign(s, :edit_logline, params["logline"]), else: s end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_edit", _, socket) do
    screenplay = Screenplays.get_screenplay!(socket.assigns.edit_screenplay_id)
    user_id = socket.assigns.current_user.id

    if screenplay.writer_id == user_id do
      # Process replacement PDF if any
      pdf_result = process_replace_pdf_upload(socket, user_id)

      attrs = %{
        "title" => socket.assigns.edit_title,
        "genre" => socket.assigns.edit_genre,
        "logline" => socket.assigns.edit_logline
      }

      # Add PDF URL if a new PDF was uploaded
      attrs = case pdf_result do
        {:ok, %{url: url}} -> Map.put(attrs, "pdf_url", url)
        _ -> attrs
      end

      case Screenplays.update_screenplay(screenplay, attrs) do
        {:ok, updated} ->
          # Notify performers if there are audio versions
          notify_performers_of_update(updated)

          message = case pdf_result do
            {:ok, _} -> "Screenplay updated with new script (v#{updated.version})!"
            _ -> "Screenplay updated successfully!"
          end

          {:noreply,
           socket
           |> put_flash(:info, message)
           |> assign(:edit_screenplay_id, nil)
           |> load_screenplays(socket.assigns.current_user)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update screenplay")}
      end
    else
      {:noreply, put_flash(socket, :error, "You can only edit your own screenplays")}
    end
  end

  defp process_replace_pdf_upload(socket, user_id) do
    alias ScriptVoice.Uploads

    uploaded_files =
      consume_uploaded_entries(socket, :replace_pdf, fn %{path: temp_path}, entry ->
        if Uploads.configured?() do
          Uploads.upload_pdf(temp_path, entry.client_name, user_id)
        else
          {:ok, %{url: "/uploads/#{entry.client_name}", key: entry.client_name, size: 0}}
        end
      end)

    case uploaded_files do
      [result | _] -> result
      [] -> {:error, :no_file}
    end
  end

  defp notify_performers_of_update(screenplay) do
    audio_versions = Audio.list_audio_versions_for_screenplay(screenplay.id)

    for audio <- audio_versions do
      if audio.submitted_by_id do
        # Check if performer's recording was for an older version
        version_warning = if (audio.script_version || 1) < (screenplay.version || 1) do
          " Your recording was made for version #{audio.script_version || 1}, the script is now on version #{screenplay.version}."
        else
          ""
        end

        Notifications.create_notification(%{
          user_id: audio.submitted_by_id,
          type: "screenplay_updated",
          title: "Screenplay Updated (v#{screenplay.version || 1})",
          body: "The screenplay \"#{screenplay.title}\" has been updated by the writer.#{version_warning}",
          action_url: "/screenplay/#{screenplay.id}"
        })
      end
    end
  end

  @impl true
  def handle_event("delete_screenplay", %{"id" => id}, socket) do
    screenplay = Screenplays.get_screenplay!(id)

    # Only allow deletion if user owns the screenplay
    if screenplay.writer_id == socket.assigns.current_user.id do
      # Notify performers who have audio for this screenplay before deletion
      notify_performers_of_deletion(screenplay)

      case Screenplays.delete_screenplay(screenplay) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Screenplay \"#{screenplay.title}\" and all associated audio deleted.")
           |> load_screenplays(socket.assigns.current_user)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete screenplay")}
      end
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own screenplays")}
    end
  end

  @impl true
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :delete_confirm_id, id)}
  end

  @impl true
  def handle_event("cancel_delete", _, socket) do
    {:noreply, assign(socket, :delete_confirm_id, nil)}
  end

  defp notify_performers_of_deletion(screenplay) do
    # Get all performers who have audio for this screenplay
    audio_versions = Audio.list_audio_versions_for_screenplay(screenplay.id)

    for audio <- audio_versions do
      if audio.submitted_by_id do
        Notifications.create_notification(%{
          user_id: audio.submitted_by_id,
          type: "screenplay_deleted",
          title: "Screenplay Deleted",
          body: "The screenplay \"#{screenplay.title}\" has been deleted by the writer. Your audio recording has also been removed.",
          action_url: nil
        })
      end
    end
  end

  @impl true
  def handle_event("publish_screenplay", _, socket) do
    user_id = socket.assigns.current_user.id

    # Process uploaded PDF if any
    pdf_result = process_pdf_upload(socket, user_id)

    screenplay_attrs = %{
      "title" => socket.assigns.upload_title,
      "genre" => socket.assigns.upload_genre,
      "logline" => socket.assigns.upload_logline,
      "characters" => socket.assigns.upload_characters
    }

    # Add PDF URL if upload succeeded
    screenplay_attrs = case pdf_result do
      {:ok, %{url: url}} -> Map.put(screenplay_attrs, "pdf_url", url)
      _ -> screenplay_attrs
    end

    case Screenplays.create_screenplay(screenplay_attrs, socket.assigns.current_user) do
      {:ok, screenplay} ->
        {:noreply,
         socket
         |> put_flash(:info, "Screenplay \"#{screenplay.title}\" published successfully!")
         |> assign(:show_upload_form, false)
         |> assign(:upload_step, 1)
         |> assign(:upload_title, "")
         |> assign(:upload_genre, "Drama")
         |> assign(:upload_logline, "")
         |> assign(:upload_characters, [])
         |> load_screenplays(socket.assigns.current_user)}

      {:error, changeset} ->
        error = format_errors(changeset)
        {:noreply, assign(socket, :upload_error, error)}
    end
  end

  defp process_pdf_upload(socket, user_id) do
    alias ScriptVoice.Uploads

    uploaded_files =
      consume_uploaded_entries(socket, :pdf, fn %{path: temp_path}, entry ->
        if Uploads.configured?() do
          Uploads.upload_pdf(temp_path, entry.client_name, user_id)
        else
          # Local fallback - just return a placeholder
          {:ok, %{url: "/uploads/#{entry.client_name}", key: entry.client_name, size: 0}}
        end
      end)

    case uploaded_files do
      [result | _] -> result
      [] -> {:error, :no_file}
    end
  end

  # Profile events
  @impl true
  def handle_event("update_profile", %{"name" => name, "bio" => bio}, socket) do
    case Accounts.update_user(socket.assigns.current_user, %{name: name, bio: bio}) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> put_flash(:info, "Profile updated successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update profile")}
    end
  end

  @impl true
  def handle_info({:new_notification, notification}, socket) do
    notifications = [notification | socket.assigns.notifications] |> Enum.take(10)
    unread_count = socket.assigns.unread_count + 1

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)
     |> put_flash(:info, notification.title)}
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> Accounts.get_user(user_id)
    end
  end

  defp format_money(cents) when is_integer(cents) do
    dollars = cents / 100
    "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
  end
  defp format_money(_), do: "$0.00"

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  # ===========================================================================
  # Render
  # ===========================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-4xl mx-auto px-4 py-4 sm:py-6">
        <!-- Header -->
        <div class="mb-4 sm:mb-6">
          <h1 class="text-xl sm:text-2xl font-bold text-gray-900">
            Welcome, <%= @current_user.name %>
          </h1>
        </div>

        <!-- Tabs - Horizontal scroll on mobile -->
        <div class="mb-4 sm:mb-6 -mx-4 px-4 sm:mx-0 sm:px-0">
          <div class="flex gap-1 overflow-x-auto pb-2 scrollbar-hide">
            <%= for {id, label, icon} <- @tabs do %>
              <button
                phx-click="change_tab"
                phx-value-tab={id}
                class={[
                  "flex items-center gap-2 px-4 py-2.5 rounded-lg text-sm font-medium whitespace-nowrap transition touch-manipulation",
                  id == @active_tab && "bg-emerald-600 text-white",
                  id != @active_tab && "bg-white text-gray-600 hover:bg-gray-100 border"
                ]}
              >
                <.icon name={icon} class="w-4 h-4" />
                <span><%= label %></span>
                <%= if id == "commissions" && length(@writer_commissions ++ @performer_commissions) > 0 do %>
                  <span class={[
                    "px-1.5 py-0.5 text-xs rounded-full",
                    id == @active_tab && "bg-white/20",
                    id != @active_tab && "bg-emerald-100 text-emerald-700"
                  ]}>
                    <%= length(@writer_commissions ++ @performer_commissions) %>
                  </span>
                <% end %>
              </button>
            <% end %>
          </div>
        </div>

        <!-- Tab Content -->
        <div class="space-y-4">
          <%= case @active_tab do %>
            <% "overview" -> %>
              <.overview_tab
                current_user={@current_user}
                stats={@stats}
                screenplays={@screenplays}
                audio_versions={@audio_versions}
                notifications={@notifications}
                unread_count={@unread_count}
                writer_commissions={@writer_commissions}
                performer_commissions={@performer_commissions}
                pricing_set={assigns[:pricing_set]}
                stripe_ready={assigns[:stripe_ready]}
              />

            <% "screenplays" -> %>
              <.screenplays_tab
                screenplays={@screenplays}
                show_upload_form={@show_upload_form}
                upload_step={@upload_step}
                upload_title={@upload_title}
                upload_genre={@upload_genre}
                upload_logline={@upload_logline}
                upload_characters={@upload_characters}
                upload_error={@upload_error}
                uploads={@uploads}
                delete_confirm_id={@delete_confirm_id}
                edit_screenplay_id={@edit_screenplay_id}
                edit_title={@edit_title}
                edit_genre={@edit_genre}
                edit_logline={@edit_logline}
              />

            <% "audio" -> %>
              <.audio_tab audio_versions={@audio_versions} />

            <% "commissions" -> %>
              <.commissions_tab
                current_user={@current_user}
                writer_commissions={@writer_commissions}
                performer_commissions={@performer_commissions}
                filter={@commission_filter}
              />

            <% "profile" -> %>
              <.profile_tab current_user={@current_user} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ===========================================================================
  # Overview Tab
  # ===========================================================================

  defp overview_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Setup Alert for performers -->
      <%= if @current_user.user_type == "voice_artist" && (!@pricing_set || !@stripe_ready) do %>
        <div class="bg-amber-50 border border-amber-200 rounded-xl p-4">
          <div class="flex items-start gap-3">
            <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-amber-600 mt-0.5" />
            <div class="flex-1">
              <h3 class="font-semibold text-amber-900">Complete Your Setup</h3>
              <ul class="text-sm text-amber-700 mt-2 space-y-1">
                <%= if !@pricing_set do %>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-x-circle" class="w-4 h-4" />
                    <.link navigate={~p"/settings/pricing"} class="underline">Set up your pricing</.link>
                  </li>
                <% end %>
                <%= if !@stripe_ready do %>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-x-circle" class="w-4 h-4" />
                    <.link navigate={~p"/settings/payments"} class="underline">Connect Stripe</.link>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Stats -->
      <%= if @stats do %>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <%= if @current_user.user_type == "writer" do %>
            <.stat_card icon="hero-document-text" label="Scripts" value={length(@screenplays)} color="purple" />
            <.stat_card icon="hero-check-circle" label="Completed" value={@stats.completed_count} color="green" />
            <.stat_card icon="hero-clock" label="Pending" value={@stats.pending_count} color="amber" />
            <.stat_card icon="hero-banknotes" label="Spent" value={format_money(@stats.total_spent_cents)} color="blue" />
          <% else %>
            <.stat_card icon="hero-microphone" label="Recordings" value={length(@audio_versions)} color="purple" />
            <.stat_card icon="hero-check-circle" label="Completed" value={@stats.completed_count} color="green" />
            <.stat_card icon="hero-play" label="Active" value={@stats.active_count} color="blue" />
            <.stat_card icon="hero-banknotes" label="Earned" value={format_money(@stats.total_earned_cents)} color="emerald" />
          <% end %>
        </div>
      <% end %>

      <!-- Quick Actions + Notifications Grid -->
      <div class="grid sm:grid-cols-2 gap-4">
        <!-- Recent Activity -->
        <div class="bg-white rounded-xl border p-4">
          <h3 class="font-semibold text-gray-900 mb-3">Recent Activity</h3>
          <%= if @current_user.user_type == "writer" && length(@screenplays) > 0 do %>
            <div class="space-y-2">
              <%= for sp <- Enum.take(@screenplays, 3) do %>
                <.link navigate={~p"/screenplay/#{sp.id}"} class="flex items-center justify-between p-2 rounded-lg hover:bg-gray-50">
                  <div class="truncate">
                    <div class="font-medium text-sm text-gray-900 truncate"><%= sp.title %></div>
                    <div class="text-xs text-gray-500"><%= sp.genre %></div>
                  </div>
                  <div class="flex items-center gap-1 text-gray-400 text-sm">
                    <.icon name="hero-heart" class="w-3 h-3" />
                    <%= sp.likes %>
                  </div>
                </.link>
              <% end %>
            </div>
          <% else %>
            <%= if @current_user.user_type == "voice_artist" && length(@audio_versions) > 0 do %>
              <div class="space-y-2">
                <%= for audio <- Enum.take(@audio_versions, 3) do %>
                  <.link navigate={~p"/screenplay/#{audio.screenplay_id}"} class="flex items-center justify-between p-2 rounded-lg hover:bg-gray-50">
                    <div class="truncate">
                      <div class="font-medium text-sm text-gray-900 truncate"><%= audio.screenplay.title %></div>
                      <div class="text-xs text-gray-500"><%= AudioVersion.display_duration(audio) %></div>
                    </div>
                    <div class="flex items-center gap-1 text-gray-400 text-sm">
                      <.icon name="hero-heart" class="w-3 h-3" />
                      <%= audio.likes %>
                    </div>
                  </.link>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-500 text-sm">No recent activity yet</p>
            <% end %>
          <% end %>
        </div>

        <!-- Notifications -->
        <div class="bg-white rounded-xl border p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-semibold text-gray-900 flex items-center gap-2">
              Notifications
              <%= if @unread_count > 0 do %>
                <span class="px-1.5 py-0.5 text-xs font-medium bg-red-100 text-red-700 rounded-full">
                  <%= @unread_count %>
                </span>
              <% end %>
            </h3>
            <%= if @unread_count > 0 do %>
              <button phx-click="mark_all_read" class="text-xs text-emerald-600 hover:underline">
                Mark read
              </button>
            <% end %>
          </div>
          <%= if Enum.empty?(@notifications) do %>
            <p class="text-gray-500 text-sm">No notifications</p>
          <% else %>
            <div class="space-y-2">
              <%= for n <- Enum.take(@notifications, 4) do %>
                <div class={["p-2 rounded-lg text-sm", is_nil(n.read_at) && "bg-emerald-50", !is_nil(n.read_at) && "bg-gray-50"]}>
                  <div class="font-medium text-gray-900"><%= n.title %></div>
                  <div class="text-xs text-gray-500 mt-0.5"><%= format_time_ago(n.inserted_at) %></div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Active Commissions Preview -->
      <% active = Enum.filter(@writer_commissions ++ @performer_commissions, fn c -> c.status in ["accepted", "in_progress", "submitted"] end) %>
      <%= if length(active) > 0 do %>
        <div class="bg-white rounded-xl border p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-semibold text-gray-900">Active Commissions</h3>
            <button phx-click="change_tab" phx-value-tab="commissions" class="text-sm text-emerald-600 hover:underline">
              View all
            </button>
          </div>
          <div class="space-y-2">
            <%= for c <- Enum.take(active, 3) do %>
              <.link navigate={~p"/commissions/#{c.id}"} class="flex items-center justify-between p-3 rounded-lg bg-gray-50 hover:bg-gray-100">
                <div class="truncate">
                  <div class="font-medium text-gray-900 truncate"><%= c.screenplay.title %></div>
                  <div class="text-sm text-gray-500">
                    <%= if c.writer_id == @current_user.id, do: "with #{c.performer.name}", else: "for #{c.writer.name}" %>
                  </div>
                </div>
                <.status_badge status={c.status} />
              </.link>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ===========================================================================
  # Screenplays Tab (Writers)
  # ===========================================================================

  defp screenplays_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Upload Button / Form Toggle -->
      <div class="flex justify-between items-center">
        <h2 class="text-lg font-semibold text-gray-900">My Screenplays</h2>
        <button
          phx-click="toggle_upload_form"
          class={[
            "inline-flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition",
            !@show_upload_form && "bg-emerald-600 text-white hover:bg-emerald-700",
            @show_upload_form && "bg-gray-200 text-gray-700 hover:bg-gray-300"
          ]}
        >
          <%= if @show_upload_form do %>
            <.icon name="hero-x-mark" class="w-4 h-4" />
            Cancel
          <% else %>
            <.icon name="hero-plus" class="w-4 h-4" />
            New Script
          <% end %>
        </button>
      </div>

      <!-- Upload Form (Inline) -->
      <%= if @show_upload_form do %>
        <div class="bg-white rounded-xl border p-4 sm:p-6">
          <%= if @upload_error do %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
              <.icon name="hero-exclamation-circle" class="w-5 h-5" />
              <%= @upload_error %>
            </div>
          <% end %>

          <%= if @upload_step == 1 do %>
            <h3 class="font-semibold text-gray-900 mb-4">Upload New Screenplay</h3>
            <form phx-change="validate_upload" phx-submit="continue_to_characters" class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Title *</label>
                <input
                  type="text"
                  name="title"
                  value={@upload_title}
                  class="w-full border rounded-lg px-3 py-2.5 focus:border-emerald-500 focus:ring-emerald-500"
                  placeholder="Your screenplay title"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Genre *</label>
                <select name="genre" class="w-full border rounded-lg px-3 py-2.5 focus:border-emerald-500 focus:ring-emerald-500">
                  <%= for genre <- Screenplay.genres() do %>
                    <option value={genre} selected={genre == @upload_genre}><%= genre %></option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Logline *</label>
                <textarea
                  name="logline"
                  rows="3"
                  class="w-full border rounded-lg px-3 py-2.5 focus:border-emerald-500 focus:ring-emerald-500"
                  placeholder="One sentence that captures your story..."
                ><%= @upload_logline %></textarea>
              </div>

              <div
                class="border-2 border-dashed rounded-lg p-6 text-center cursor-pointer hover:border-emerald-400 transition"
                phx-drop-target={@uploads.pdf.ref}
              >
                <.live_file_input upload={@uploads.pdf} class="sr-only" />
                <label for={@uploads.pdf.ref} class="cursor-pointer block">
                  <.icon name="hero-document-text" class="w-8 h-8 mx-auto mb-2 text-gray-400" />
                  <p class="text-sm text-gray-500">Drop PDF or <span class="text-emerald-600 font-medium">click to upload</span></p>
                </label>
                <%= for entry <- @uploads.pdf.entries do %>
                  <div class="mt-3 bg-emerald-50 rounded-lg p-2">
                    <p class="text-sm text-emerald-600 font-medium"><%= entry.client_name %></p>
                  </div>
                <% end %>
              </div>

              <button type="submit" class="w-full bg-emerald-600 text-white py-3 rounded-lg font-medium hover:bg-emerald-700 transition">
                Continue to Add Characters
              </button>
            </form>
          <% else %>
            <div class="flex items-center justify-between mb-4">
              <h3 class="font-semibold text-gray-900">Add Characters</h3>
              <button phx-click="back_to_step_1" class="text-sm text-gray-500 hover:text-gray-700">
                ← Back
              </button>
            </div>

            <p class="text-sm text-gray-600 mb-4">Add your screenplay's characters. Voice artists will see this when browsing.</p>

            <div class="space-y-3 max-h-[300px] overflow-y-auto mb-4">
              <%= for {char, index} <- Enum.with_index(@upload_characters) do %>
                <div class="border rounded-lg p-3">
                  <div class="flex items-center justify-between mb-2">
                    <input
                      type="text"
                      name="value"
                      value={char.name}
                      phx-blur="update_character"
                      phx-debounce="blur"
                      phx-value-index={index}
                      phx-value-field="name"
                      class="font-medium bg-transparent border-b border-transparent hover:border-gray-300 focus:border-emerald-500 focus:outline-none"
                      style="width: 120px;"
                    />
                    <div class="flex items-center gap-2">
                      <select
                        name="value"
                        phx-change="update_character"
                        phx-value-index={index}
                        phx-value-field="gender"
                        class="text-sm border rounded px-2 py-1"
                      >
                        <%= for gender <- Character.genders() do %>
                          <option value={gender} selected={gender == char.gender}><%= gender %></option>
                        <% end %>
                      </select>
                      <button type="button" phx-click="remove_character" phx-value-index={index} class="text-gray-400 hover:text-red-500">
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                  <input
                    type="text"
                    name="value"
                    value={char.description || ""}
                    phx-blur="update_character"
                    phx-debounce="blur"
                    phx-value-index={index}
                    phx-value-field="description"
                    placeholder="Character description..."
                    class="w-full text-sm bg-transparent border-b border-transparent hover:border-gray-300 focus:border-emerald-500 focus:outline-none"
                  />
                </div>
              <% end %>

              <button
                type="button"
                phx-click="add_character"
                class="w-full border-2 border-dashed rounded-lg py-3 text-gray-500 hover:border-gray-400 hover:text-gray-600 text-sm"
              >
                + Add Character
              </button>
            </div>

            <button
              phx-click="publish_screenplay"
              class="w-full bg-emerald-600 text-white py-3 rounded-lg font-medium hover:bg-emerald-700 transition"
            >
              Publish Screenplay
            </button>
          <% end %>
        </div>
      <% end %>

      <!-- Screenplays List -->
      <%= if Enum.empty?(@screenplays) && !@show_upload_form do %>
        <div class="bg-white rounded-xl border p-8 text-center">
          <.icon name="hero-document-text" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <h3 class="font-semibold text-gray-900 mb-2">No screenplays yet</h3>
          <p class="text-gray-600 mb-4">Upload your first screenplay to get started</p>
        </div>
      <% else %>
        <div class="space-y-3">
          <%= for sp <- @screenplays do %>
            <div class="bg-white rounded-xl border hover:border-emerald-300 transition">
              <%= cond do %>
                <% @delete_confirm_id == sp.id -> %>
                  <!-- Delete Confirmation -->
                  <div class="p-4">
                    <div class="flex items-start gap-3 mb-4">
                      <div class="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
                        <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-red-600" />
                      </div>
                      <div>
                        <h3 class="font-semibold text-gray-900">Delete "<%= sp.title %>"?</h3>
                        <p class="text-sm text-gray-600 mt-1">
                          This will permanently delete this screenplay
                          <%= if (sp.audio_version_count || 0) > 0 do %>
                            and <span class="font-medium text-red-600"><%= sp.audio_version_count %> audio recording<%= if sp.audio_version_count != 1, do: "s" %></span>.
                            Performers will be notified.
                          <% else %>
                            .
                          <% end %>
                        </p>
                      </div>
                    </div>
                    <div class="flex gap-3">
                      <button
                        phx-click="cancel_delete"
                        class="flex-1 px-4 py-2 border rounded-lg text-gray-700 hover:bg-gray-50 font-medium"
                      >
                        Cancel
                      </button>
                      <button
                        phx-click="delete_screenplay"
                        phx-value-id={sp.id}
                        class="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 font-medium"
                      >
                        Delete
                      </button>
                    </div>
                  </div>

                <% @edit_screenplay_id == sp.id -> %>
                  <!-- Edit Form -->
                  <div class="p-4">
                    <form phx-change="validate_edit" phx-submit="save_edit" class="space-y-4">
                      <div class="flex items-center justify-between mb-2">
                        <h3 class="font-semibold text-gray-900">Edit Screenplay</h3>
                        <button type="button" phx-click="cancel_edit" class="text-gray-400 hover:text-gray-600">
                          <.icon name="hero-x-mark" class="w-5 h-5" />
                        </button>
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
                        <input
                          type="text"
                          name="title"
                          value={@edit_title}
                          class="w-full border rounded-lg px-3 py-2 text-sm focus:border-emerald-500 focus:ring-emerald-500"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Genre</label>
                        <select name="genre" class="w-full border rounded-lg px-3 py-2 text-sm focus:border-emerald-500 focus:ring-emerald-500">
                          <%= for genre <- Screenplay.genres() do %>
                            <option value={genre} selected={genre == @edit_genre}><%= genre %></option>
                          <% end %>
                        </select>
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Logline</label>
                        <textarea
                          name="logline"
                          rows="2"
                          class="w-full border rounded-lg px-3 py-2 text-sm focus:border-emerald-500 focus:ring-emerald-500"
                        ><%= @edit_logline %></textarea>
                      </div>

                      <!-- Replace Script PDF -->
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                          Replace Script (Optional)
                        </label>
                        <div
                          class="border-2 border-dashed rounded-lg p-4 text-center cursor-pointer hover:border-emerald-400 transition"
                          phx-drop-target={@uploads.replace_pdf.ref}
                        >
                          <.live_file_input upload={@uploads.replace_pdf} class="sr-only" />
                          <label for={@uploads.replace_pdf.ref} class="cursor-pointer block">
                            <.icon name="hero-arrow-up-tray" class="w-6 h-6 mx-auto mb-1 text-gray-400" />
                            <p class="text-xs text-gray-500">
                              <%= if sp.pdf_url do %>
                                Upload new PDF to replace current script
                              <% else %>
                                Upload PDF script
                              <% end %>
                            </p>
                          </label>
                          <%= for entry <- @uploads.replace_pdf.entries do %>
                            <div class="mt-2 bg-emerald-50 rounded-lg p-2">
                              <p class="text-xs text-emerald-600 font-medium"><%= entry.client_name %></p>
                            </div>
                          <% end %>
                        </div>
                        <%= if sp.pdf_url do %>
                          <p class="text-xs text-gray-500 mt-1">
                            Current: v<%= sp.version || 1 %> - Uploading new script will create v<%= (sp.version || 1) + 1 %>
                          </p>
                        <% end %>
                      </div>

                      <%= if (sp.audio_version_count || 0) > 0 do %>
                        <div class="bg-amber-50 border border-amber-200 rounded-lg p-3 text-sm text-amber-800">
                          <.icon name="hero-exclamation-triangle" class="w-4 h-4 inline" />
                          This screenplay has <%= sp.audio_version_count %> audio recording<%= if sp.audio_version_count != 1, do: "s" %>.
                          Performers will be notified of updates.
                        </div>
                      <% end %>

                      <div class="flex gap-3">
                        <button
                          type="button"
                          phx-click="cancel_edit"
                          class="flex-1 px-4 py-2 border rounded-lg text-gray-700 hover:bg-gray-50 font-medium"
                        >
                          Cancel
                        </button>
                        <button
                          type="submit"
                          class="flex-1 px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 font-medium"
                        >
                          Save Changes
                        </button>
                      </div>
                    </form>
                  </div>

                <% true -> %>
                  <!-- Normal View -->
                  <div class="p-4">
                    <div class="flex items-start justify-between">
                      <.link navigate={~p"/screenplay/#{sp.id}"} class="flex-1 min-w-0">
                        <div class="flex items-center gap-2 mb-1">
                          <h3 class="font-semibold text-gray-900 truncate"><%= sp.title %></h3>
                          <span class="px-2 py-0.5 text-xs font-medium bg-gray-100 text-gray-700 rounded"><%= sp.genre %></span>
                        </div>
                        <p class="text-sm text-gray-600 line-clamp-2"><%= sp.logline %></p>
                        <div class="flex items-center gap-4 mt-2 text-sm text-gray-500">
                          <span><%= sp.page_count || "?" %> pages</span>
                          <span class="flex items-center gap-1">
                            <.icon name="hero-heart" class="w-4 h-4" />
                            <%= sp.likes %>
                          </span>
                          <span class="flex items-center gap-1">
                            <.icon name="hero-microphone" class="w-4 h-4" />
                            <%= sp.audio_version_count || 0 %>
                          </span>
                          <span class="flex items-center gap-1 text-purple-600">
                            v<%= sp.version || 1 %>
                          </span>
                        </div>
                      </.link>
                      <!-- Action Buttons -->
                      <div class="flex items-center gap-2 ml-3 flex-shrink-0">
                        <button
                          phx-click="start_edit"
                          phx-value-id={sp.id}
                          class="p-2 text-emerald-600 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition"
                          title="Edit screenplay"
                        >
                          <.icon name="hero-pencil-square" class="w-5 h-5" />
                        </button>
                        <button
                          phx-click="confirm_delete"
                          phx-value-id={sp.id}
                          class="p-2 text-red-600 bg-red-50 hover:bg-red-100 rounded-lg transition"
                          title="Delete screenplay"
                        >
                          <.icon name="hero-trash" class="w-5 h-5" />
                        </button>
                      </div>
                    </div>
                  </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ===========================================================================
  # Audio Tab (Performers)
  # ===========================================================================

  defp audio_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <h2 class="text-lg font-semibold text-gray-900">My Recordings</h2>
        <.link navigate={~p"/browse"} class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 transition">
          <.icon name="hero-magnifying-glass" class="w-4 h-4" />
          Find Scripts
        </.link>
      </div>

      <%= if Enum.empty?(@audio_versions) do %>
        <div class="bg-white rounded-xl border p-8 text-center">
          <.icon name="hero-microphone" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <h3 class="font-semibold text-gray-900 mb-2">No recordings yet</h3>
          <p class="text-gray-600 mb-4">Browse screenplays and record your first performance</p>
          <.link navigate={~p"/browse"} class="text-emerald-600 font-medium hover:underline">
            Browse Screenplays →
          </.link>
        </div>
      <% else %>
        <div class="space-y-3">
          <%= for audio <- @audio_versions do %>
            <% script_version = audio.script_version || 1 %>
            <% current_version = audio.screenplay.version || 1 %>
            <% is_outdated = script_version < current_version %>
            <.link navigate={~p"/screenplay/#{audio.screenplay_id}"} class={["block bg-white rounded-xl border p-4 transition", is_outdated && "border-amber-300", !is_outdated && "hover:border-emerald-300"]}>
              <div class="flex items-center justify-between">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <h3 class="font-semibold text-gray-900 truncate"><%= audio.screenplay.title %></h3>
                    <%= if is_outdated do %>
                      <span class="px-2 py-0.5 text-xs font-medium bg-amber-100 text-amber-700 rounded-full flex items-center gap-1">
                        <.icon name="hero-exclamation-triangle" class="w-3 h-3" />
                        Script updated
                      </span>
                    <% end %>
                  </div>
                  <div class="flex items-center gap-4 mt-1 text-sm text-gray-500">
                    <span><%= AudioVersion.display_duration(audio) %></span>
                    <span class="flex items-center gap-1">
                      <.icon name="hero-heart" class="w-4 h-4" />
                      <%= audio.likes %>
                    </span>
                    <span class="text-purple-600">
                      Recorded v<%= script_version %><%= if is_outdated, do: " → v#{current_version}" %>
                    </span>
                  </div>
                </div>
                <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400" />
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ===========================================================================
  # Commissions Tab
  # ===========================================================================

  defp commissions_tab(assigns) do
    all_commissions = assigns.writer_commissions ++ assigns.performer_commissions

    filtered = case assigns.filter do
      "all" -> all_commissions
      "active" -> Enum.filter(all_commissions, & &1.status in ["accepted", "in_progress", "submitted", "revision_requested"])
      "pending" -> Enum.filter(all_commissions, & &1.status == "pending")
      "completed" -> Enum.filter(all_commissions, & &1.status == "completed")
      _ -> all_commissions
    end

    assigns = assign(assigns, :filtered_commissions, filtered)
    assigns = assign(assigns, :all_commissions, all_commissions)

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-gray-900">Commissions</h2>
      </div>

      <!-- Filter Pills -->
      <div class="flex gap-2 overflow-x-auto pb-2 -mx-4 px-4 sm:mx-0 sm:px-0">
        <%= for {filter, label} <- [{"all", "All"}, {"active", "Active"}, {"pending", "Pending"}, {"completed", "Completed"}] do %>
          <button
            phx-click="filter_commissions"
            phx-value-filter={filter}
            class={[
              "px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition",
              filter == @filter && "bg-emerald-600 text-white",
              filter != @filter && "bg-white border text-gray-600 hover:bg-gray-50"
            ]}
          >
            <%= label %>
            <%= if filter == "all" do %>
              (<%= length(@all_commissions) %>)
            <% end %>
          </button>
        <% end %>
      </div>

      <%= if Enum.empty?(@filtered_commissions) do %>
        <div class="bg-white rounded-xl border p-8 text-center">
          <.icon name="hero-clipboard-document-list" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <h3 class="font-semibold text-gray-900 mb-2">No commissions found</h3>
          <p class="text-gray-600">
            <%= if @filter != "all", do: "Try a different filter", else: "Commissions will appear here" %>
          </p>
        </div>
      <% else %>
        <div class="space-y-3">
          <%= for c <- @filtered_commissions do %>
            <.link navigate={~p"/commissions/#{c.id}"} class="block bg-white rounded-xl border p-4 hover:border-emerald-300 transition">
              <div class="flex items-center justify-between">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-1">
                    <h3 class="font-semibold text-gray-900 truncate"><%= c.screenplay.title %></h3>
                    <.status_badge status={c.status} />
                  </div>
                  <div class="text-sm text-gray-500">
                    <%= if c.writer_id == @current_user.id do %>
                      <span class="text-purple-600">As Writer</span> · with <%= c.performer.name %>
                    <% else %>
                      <span class="text-pink-600">As Performer</span> · for <%= c.writer.name %>
                    <% end %>
                  </div>
                  <div class="text-sm text-gray-500 mt-1">
                    <%= format_money(c.agreed_price_cents || c.requested_price_cents) %>
                  </div>
                </div>
                <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400 flex-shrink-0" />
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ===========================================================================
  # Profile Tab
  # ===========================================================================

  defp profile_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <h2 class="text-lg font-semibold text-gray-900">My Profile</h2>

      <div class="bg-white rounded-xl border p-4 sm:p-6">
        <form phx-submit="update_profile" class="space-y-4">
          <div class="flex items-center gap-4 mb-6">
            <div class="w-16 h-16 rounded-full bg-emerald-100 flex items-center justify-center text-emerald-600 text-2xl font-bold">
              <%= String.first(@current_user.name) %>
            </div>
            <div>
              <div class="font-semibold text-gray-900"><%= @current_user.name %></div>
              <div class="text-sm text-gray-500 capitalize"><%= String.replace(@current_user.user_type, "_", " ") %></div>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
            <input
              type="text"
              name="name"
              value={@current_user.name}
              class="w-full border rounded-lg px-3 py-2.5 focus:border-emerald-500 focus:ring-emerald-500"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Bio</label>
            <textarea
              name="bio"
              rows="4"
              class="w-full border rounded-lg px-3 py-2.5 focus:border-emerald-500 focus:ring-emerald-500"
              placeholder="Tell others about yourself..."
            ><%= @current_user.bio %></textarea>
          </div>

          <button type="submit" class="w-full sm:w-auto px-6 py-2.5 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 transition">
            Save Changes
          </button>
        </form>
      </div>

      <!-- Quick Links -->
      <div class="bg-white rounded-xl border p-4">
        <h3 class="font-semibold text-gray-900 mb-3">Quick Links</h3>
        <div class="space-y-2">
          <.link navigate={~p"/profile/#{@current_user.id}"} class="flex items-center justify-between p-3 rounded-lg hover:bg-gray-50">
            <span class="text-gray-700">View Public Profile</span>
            <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4 text-gray-400" />
          </.link>
          <%= if @current_user.user_type == "voice_artist" do %>
            <.link navigate={~p"/settings/pricing"} class="flex items-center justify-between p-3 rounded-lg hover:bg-gray-50">
              <span class="text-gray-700">Pricing Settings</span>
              <.icon name="hero-chevron-right" class="w-4 h-4 text-gray-400" />
            </.link>
            <.link navigate={~p"/settings/payments"} class="flex items-center justify-between p-3 rounded-lg hover:bg-gray-50">
              <span class="text-gray-700">Payment Settings</span>
              <.icon name="hero-chevron-right" class="w-4 h-4 text-gray-400" />
            </.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ===========================================================================
  # Shared Components
  # ===========================================================================

  defp stat_card(assigns) do
    colors = %{
      "purple" => "bg-purple-100 text-purple-600",
      "green" => "bg-green-100 text-green-600",
      "amber" => "bg-amber-100 text-amber-600",
      "blue" => "bg-blue-100 text-blue-600",
      "emerald" => "bg-emerald-100 text-emerald-600"
    }

    assigns = assign(assigns, :color_class, Map.get(colors, assigns.color, "bg-gray-100 text-gray-600"))

    ~H"""
    <div class="bg-white rounded-xl border p-3 sm:p-4">
      <div class={["w-8 h-8 rounded-lg flex items-center justify-center mb-2", @color_class]}>
        <.icon name={@icon} class="w-4 h-4" />
      </div>
      <div class="text-xl sm:text-2xl font-bold text-gray-900"><%= @value %></div>
      <div class="text-xs sm:text-sm text-gray-500"><%= @label %></div>
    </div>
    """
  end

  defp status_badge(assigns) do
    colors = %{
      "pending" => "bg-amber-100 text-amber-700",
      "accepted" => "bg-blue-100 text-blue-700",
      "in_progress" => "bg-purple-100 text-purple-700",
      "submitted" => "bg-indigo-100 text-indigo-700",
      "revision_requested" => "bg-orange-100 text-orange-700",
      "completed" => "bg-green-100 text-green-700",
      "cancelled" => "bg-gray-100 text-gray-700",
      "declined" => "bg-red-100 text-red-700"
    }

    labels = %{
      "pending" => "Pending",
      "accepted" => "Accepted",
      "in_progress" => "In Progress",
      "submitted" => "Submitted",
      "revision_requested" => "Revision",
      "completed" => "Completed",
      "cancelled" => "Cancelled",
      "declined" => "Declined"
    }

    assigns = assign(assigns, :color, Map.get(colors, assigns.status, "bg-gray-100 text-gray-700"))
    assigns = assign(assigns, :label, Map.get(labels, assigns.status, assigns.status))

    ~H"""
    <span class={["px-2 py-0.5 text-xs font-medium rounded-full whitespace-nowrap", @color]}>
      <%= @label %>
    </span>
    """
  end

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
