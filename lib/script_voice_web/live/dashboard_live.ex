defmodule ScriptVoiceWeb.DashboardLive do
  @moduledoc """
  User dashboard - the central hub for users to manage their ScriptVoice activity.
  Tabbed interface with all functionality in one place.
  Mobile-first design.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.{Accounts, Commissions, Notifications, Screenplays, Audio, Collectives, Projects}
  alias ScriptVoice.Audio.AudioVersion
  alias ScriptVoice.Screenplays.{Screenplay, Character, ScreenplayProject}

  @writer_tabs [
    {"overview", "Overview", "hero-home"},
    {"screenplays", "My Scripts", "hero-document-text"},
    {"commissions", "Commissions", "hero-clipboard-document-list"},
    {"profile", "Profile", "hero-user"}
  ]

  @performer_tabs [
    {"overview", "Overview", "hero-home"},
    {"audio", "My Audio", "hero-microphone"},
    {"collectives", "Collectives", "hero-user-group"},
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
      {:ok, push_navigate(socket, to: ~p"/login")}
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
    |> load_collectives(user)
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
    projects = Projects.list_projects_for_writer(user.id)
    standalone_screenplays = Projects.get_standalone_screenplays_for_writer(user.id)

    socket
    |> assign(:screenplays, screenplays)
    |> assign(:projects, projects)
    |> assign(:standalone_screenplays, standalone_screenplays)
    |> assign(:show_create_project, false)
    |> assign(:new_project_title, "")
    |> assign(:new_project_genre, "Drama")
    |> assign(:new_project_logline, "")
    |> assign(:new_project_type, "series")
  end
  defp load_screenplays(socket, _) do
    socket
    |> assign(:screenplays, [])
    |> assign(:projects, [])
    |> assign(:standalone_screenplays, [])
  end

  defp load_audio_versions(socket, %{user_type: "voice_artist"} = user) do
    audio_versions = Audio.list_audio_versions_by_user(user.id)
    assign(socket, :audio_versions, audio_versions)
  end
  defp load_audio_versions(socket, _), do: assign(socket, :audio_versions, [])

  defp load_collectives(socket, %{user_type: "voice_artist"} = user) do
    memberships = Collectives.list_memberships_for_user(user.id)
    pending_invitations = Collectives.list_pending_invitations_for_user(user.id)
    pending_requests = Collectives.list_pending_join_requests_for_user_with_messages(user.id)
    rejected_requests = Collectives.list_recent_rejected_requests_for_user(user.id) |> Map.values()

    socket
    |> assign(:memberships, memberships)
    |> assign(:pending_invitations, pending_invitations)
    |> assign(:pending_join_requests, pending_requests)
    |> assign(:rejected_join_requests, rejected_requests)
    |> assign(:show_create_collective, false)
    |> assign(:new_collective_name, "")
    |> assign(:new_collective_bio, "")
  end
  defp load_collectives(socket, _) do
    socket
    |> assign(:memberships, [])
    |> assign(:pending_invitations, [])
    |> assign(:pending_join_requests, [])
    |> assign(:rejected_join_requests, [])
  end

  defp load_commissions(socket, user) do
    # Load commissions based on user type (no mixing)
    commissions = case user.user_type do
      "writer" -> Commissions.list_commission_requests_for_writer(user.id)
      "voice_artist" -> Commissions.list_commission_requests_for_performer(user.id)
      _ -> []
    end

    socket
    |> assign(:commissions, commissions)
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
    |> assign(:upload_title, "")
    |> assign(:upload_genre, "Drama")
    |> assign(:upload_logline, "")
    |> assign(:upload_page_count, nil)
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
    # When toggling, always reset form to clean state
    {:noreply,
     socket
     |> assign(:show_upload_form, !socket.assigns.show_upload_form)
     |> assign(:upload_title, "")
     |> assign(:upload_genre, "Drama")
     |> assign(:upload_logline, "")
     |> assign(:upload_page_count, nil)
     |> assign(:upload_characters, [])
     |> assign(:upload_error, nil)}
  end

  # Project creation events
  @impl true
  def handle_event("toggle_create_project", _, socket) do
    {:noreply,
     socket
     |> assign(:show_create_project, !socket.assigns[:show_create_project])
     |> assign(:new_project_title, "")
     |> assign(:new_project_genre, "Drama")
     |> assign(:new_project_logline, "")
     |> assign(:new_project_type, "series")}
  end

  @impl true
  def handle_event("create_project", params, socket) do
    user = socket.assigns.current_user

    project_attrs = %{
      "title" => params["title"],
      "genre" => params["genre"],
      "logline" => params["logline"],
      "project_type" => params["project_type"]
    }

    case Projects.create_project(project_attrs, user) do
      {:ok, project} ->
        projects = Projects.list_projects_for_writer(user.id)
        {:noreply,
         socket
         |> assign(:projects, projects)
         |> assign(:show_create_project, false)
         |> put_flash(:info, "Project '#{project.title}' created successfully!")
         |> push_navigate(to: ~p"/project/#{project.id}")}

      {:error, changeset} ->
        error_msg = case changeset.errors do
          [{:title, {msg, _}} | _] -> "Title: #{msg}"
          [{:logline, {msg, _}} | _] -> "Logline: #{msg}"
          _ -> "Failed to create project"
        end
        {:noreply, put_flash(socket, :error, error_msg)}
    end
  end

  @impl true
  def handle_event("validate_upload", params, socket) do
    # Always preserve existing values - use params if provided, otherwise keep existing
    title = Map.get(params, "title", socket.assigns.upload_title)
    genre = Map.get(params, "genre", socket.assigns.upload_genre)
    logline = Map.get(params, "logline", socket.assigns.upload_logline)

    # For page_count, parse integer and preserve existing on empty/invalid
    page_count = case Map.get(params, "page_count") do
      nil -> socket.assigns[:upload_page_count]
      "" -> socket.assigns[:upload_page_count]
      val ->
        case Integer.parse(val) do
          {num, _} -> num
          :error -> socket.assigns[:upload_page_count]
        end
    end

    {:noreply,
     socket
     |> assign(:upload_error, nil)
     |> assign(:upload_title, title)
     |> assign(:upload_genre, genre)
     |> assign(:upload_logline, logline)
     |> assign(:upload_page_count, page_count)}
  end


  @impl true
  def handle_event("add_character", _, socket) do
    new_char = %{
      name: "",
      gender: "Any",
      estimated_lines: nil,
      description: ""
    }

    {:noreply, update(socket, :upload_characters, &(&1 ++ [new_char]))}
  end

  @impl true
  def handle_event("update_character", %{"index" => index, "field" => field} = params, socket) do
    index_int = String.to_integer(index)

    # Get value from phx-value-* attributes or dynamic input names
    value = cond do
      # For gender buttons, look for "gender" param
      Map.has_key?(params, "gender") && params["gender"] != "" -> params["gender"]
      # Legacy: check "value" param
      Map.has_key?(params, "value") && params["value"] != "" -> params["value"]
      # For form inputs with dynamic names
      Map.has_key?(params, "char_name_#{index}") -> params["char_name_#{index}"]
      Map.has_key?(params, "char_gender_#{index}") -> params["char_gender_#{index}"]
      Map.has_key?(params, "char_lines_#{index}") -> params["char_lines_#{index}"]
      true -> nil
    end

    # Convert estimated_lines to integer
    value = if field == "estimated_lines" do
      case value do
        nil -> nil
        "" -> nil
        val when is_binary(val) -> String.to_integer(val)
        val -> val
      end
    else
      value
    end

    characters =
      socket.assigns.upload_characters
      |> List.update_at(index_int, fn char ->
        Map.put(char, String.to_atom(field), value)
      end)

    {:noreply, assign(socket, :upload_characters, characters)}
  end

  # Catch-all for character updates from select elements (phx-change doesn't include phx-value-* attrs)
  @impl true
  def handle_event("update_character", %{"_target" => [target_name]} = params, socket) do
    # Parse the target name to extract index and field (e.g., "char_gender_0" -> index=0, field="gender")
    case Regex.run(~r/^char_(name|gender|lines)_(\d+)$/, target_name) do
      [_, field_short, index_str] ->
        index = String.to_integer(index_str)
        field = case field_short do
          "name" -> "name"
          "gender" -> "gender"
          "lines" -> "estimated_lines"
        end
        value = params[target_name]

        # Convert estimated_lines to integer
        value = if field == "estimated_lines" do
          case value do
            nil -> nil
            "" -> nil
            val when is_binary(val) -> String.to_integer(val)
            val -> val
          end
        else
          value
        end

        characters =
          socket.assigns.upload_characters
          |> List.update_at(index, fn char ->
            Map.put(char, String.to_atom(field), value)
          end)

        {:noreply, assign(socket, :upload_characters, characters)}

      _ ->
        # Unknown target, ignore
        {:noreply, socket}
    end
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

      # Add PDF URL and extracted text if a new PDF was uploaded
      attrs = case pdf_result do
        %{url: url, extracted_text: text} when not is_nil(text) and text != "" ->
          attrs
          |> Map.put("pdf_url", url)
          |> Map.put("script_content", text)
        %{url: url} ->
          Map.put(attrs, "pdf_url", url)
        _ ->
          attrs
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
    alias ScriptVoice.PdfExtractor

    uploaded_files =
      consume_uploaded_entries(socket, :replace_pdf, fn %{path: temp_path}, entry ->
        # First extract text from PDF
        extracted_text = case PdfExtractor.extract_text(temp_path) do
          {:ok, text} -> text
          _ -> nil
        end

        # Then upload the PDF file
        upload_result = if Uploads.configured?() do
          Uploads.upload_pdf(temp_path, entry.client_name, user_id)
        else
          Uploads.upload_pdf_local(temp_path, entry.client_name, user_id)
        end

        # Return both the upload result and extracted text
        case upload_result do
          {:ok, result} -> {:ok, Map.put(result, :extracted_text, extracted_text)}
          error -> error
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
      "page_count" => socket.assigns[:upload_page_count],
      "characters" => socket.assigns.upload_characters
    }

    # Add PDF URL and extracted text if upload succeeded
    screenplay_attrs = case pdf_result do
      %{url: url, extracted_text: text} when not is_nil(text) and text != "" ->
        screenplay_attrs
        |> Map.put("pdf_url", url)
        |> Map.put("script_content", text)
      %{url: url} ->
        Map.put(screenplay_attrs, "pdf_url", url)
      _ ->
        screenplay_attrs
    end

    case Screenplays.create_screenplay(screenplay_attrs, socket.assigns.current_user) do
      {:ok, screenplay} ->
        {:noreply,
         socket
         |> put_flash(:info, "Screenplay \"#{screenplay.title}\" published successfully!")
         |> assign(:show_upload_form, false)
         |> assign(:upload_title, "")
         |> assign(:upload_genre, "Drama")
         |> assign(:upload_logline, "")
         |> assign(:upload_page_count, nil)
         |> assign(:upload_characters, [])
         |> load_screenplays(socket.assigns.current_user)}

      {:error, changeset} ->
        error = format_errors(changeset)
        {:noreply, assign(socket, :upload_error, error)}
    end
  end

  defp process_pdf_upload(socket, user_id) do
    alias ScriptVoice.Uploads
    alias ScriptVoice.PdfExtractor

    uploaded_files =
      consume_uploaded_entries(socket, :pdf, fn %{path: temp_path}, entry ->
        # First extract text from PDF
        extracted_text = case PdfExtractor.extract_text(temp_path) do
          {:ok, text} -> text
          _ -> nil
        end

        # Then upload the PDF file
        upload_result = if Uploads.configured?() do
          Uploads.upload_pdf(temp_path, entry.client_name, user_id)
        else
          Uploads.upload_pdf_local(temp_path, entry.client_name, user_id)
        end

        # Return both the upload result and extracted text
        case upload_result do
          {:ok, result} -> {:ok, Map.put(result, :extracted_text, extracted_text)}
          error -> error
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

  # ===========================================================================
  # Collectives Event Handlers
  # ===========================================================================

  @impl true
  def handle_event("toggle_create_collective", _, socket) do
    {:noreply,
     socket
     |> assign(:show_create_collective, !socket.assigns.show_create_collective)
     |> assign(:new_collective_name, "")
     |> assign(:new_collective_bio, "")}
  end

  @impl true
  def handle_event("validate_collective", %{"name" => name, "bio" => bio}, socket) do
    {:noreply,
     socket
     |> assign(:new_collective_name, name)
     |> assign(:new_collective_bio, bio)}
  end

  @impl true
  def handle_event("create_collective", %{"name" => name, "bio" => bio}, socket) do
    user = socket.assigns.current_user

    case Collectives.create_collective(%{"name" => name, "bio" => bio}, user) do
      {:ok, collective} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{collective.name} created! Invite members from the settings page.")
         |> assign(:show_create_collective, false)
         |> assign(:new_collective_name, "")
         |> assign(:new_collective_bio, "")
         |> load_collectives(user)
         |> push_navigate(to: ~p"/collective/#{collective.slug}/settings")}

      {:error, changeset} ->
        error = format_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to create collective: #{error}")}
    end
  end

  @impl true
  def handle_event("accept_invitation", %{"id" => id}, socket) do
    invitation = Collectives.get_invitation(id)

    if invitation && invitation.invitee_id == socket.assigns.current_user.id do
      case Collectives.accept_invitation(invitation) do
        {:ok, _} ->
          # TODO: Notify the inviter
          {:noreply,
           socket
           |> put_flash(:info, "You've joined #{invitation.collective.name}!")
           |> load_collectives(socket.assigns.current_user)}

        {:error, :invitation_expired} ->
          {:noreply, put_flash(socket, :error, "This invitation has expired")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to accept invitation")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invitation not found")}
    end
  end

  @impl true
  def handle_event("decline_invitation", %{"id" => id}, socket) do
    invitation = Collectives.get_invitation(id)

    if invitation && invitation.invitee_id == socket.assigns.current_user.id do
      case Collectives.decline_invitation(invitation) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Invitation declined")
           |> load_collectives(socket.assigns.current_user)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to decline invitation")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invitation not found")}
    end
  end

  @impl true
  def handle_event("cancel_join_request", %{"id" => id}, socket) do
    request = Collectives.get_join_request(id)

    if request && request.user_id == socket.assigns.current_user.id do
      case Collectives.cancel_join_request(request) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Request cancelled")
           |> load_collectives(socket.assigns.current_user)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to cancel request")}
      end
    else
      {:noreply, put_flash(socket, :error, "Request not found")}
    end
  end

  @impl true
  def handle_event("leave_collective", %{"id" => collective_id}, socket) do
    user = socket.assigns.current_user

    case Collectives.leave_collective(collective_id, user.id) do
      {:ok, _} ->
        collective = Collectives.get_collective(collective_id)
        name = if collective, do: collective.name, else: "the collective"
        # TODO: Notify admins
        {:noreply,
         socket
         |> put_flash(:info, "You've left #{name}")
         |> load_collectives(user)}

      {:error, :last_admin} ->
        {:noreply, put_flash(socket, :error, "You can't leave - you're the last admin. Transfer admin to another member first.")}

      {:error, :not_member} ->
        {:noreply, put_flash(socket, :error, "You're not a member of this collective")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to leave collective")}
    end
  end

  @impl true
  def handle_event("send_request_message", %{"content" => content, "request_id" => request_id}, socket) do
    user = socket.assigns.current_user
    request = Collectives.get_join_request(request_id)

    if request && request.user_id == user.id do
      case Collectives.create_join_request_message(request_id, user.id, content) do
        {:ok, _message} ->
          # Notify collective admins
          collective = Collectives.get_collective(request.collective_id)
          if collective do
            collective.memberships
            |> Enum.filter(& &1.role == "admin")
            |> Enum.each(fn membership ->
              Notifications.notify_join_request_note(
                membership.user_id,
                user.name,
                collective.name,
                content,
                collective.slug
              )
            end)
          end

          {:noreply,
           socket
           |> put_flash(:info, "Message sent.")
           |> load_collectives(user)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to send message.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Request not found.")}
    end
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

        <!-- Tabs - Hidden on mobile (bottom nav used instead) -->
        <div class="hidden sm:block mb-4 sm:mb-6 -mx-4 px-4 sm:mx-0 sm:px-0">
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
                <%= if id == "commissions" && length(@commissions) > 0 do %>
                  <span class={[
                    "px-1.5 py-0.5 text-xs rounded-full",
                    id == @active_tab && "bg-white/20",
                    id != @active_tab && "bg-emerald-100 text-emerald-700"
                  ]}>
                    <%= length(@commissions) %>
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
                commissions={@commissions}
                pricing_set={assigns[:pricing_set]}
                stripe_ready={assigns[:stripe_ready]}
              />

            <% "screenplays" -> %>
              <.screenplays_tab
                screenplays={@screenplays}
                projects={@projects}
                standalone_screenplays={@standalone_screenplays}
                show_upload_form={@show_upload_form}
                show_create_project={@show_create_project}
                upload_title={@upload_title}
                upload_genre={@upload_genre}
                upload_logline={@upload_logline}
                upload_page_count={@upload_page_count}
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

            <% "collectives" -> %>
              <.collectives_tab
                current_user={@current_user}
                memberships={@memberships}
                pending_invitations={@pending_invitations}
                pending_join_requests={@pending_join_requests}
                rejected_join_requests={@rejected_join_requests}
                show_create_collective={@show_create_collective}
                new_collective_name={@new_collective_name}
                new_collective_bio={@new_collective_bio}
              />

            <% "commissions" -> %>
              <.commissions_tab
                current_user={@current_user}
                commissions={@commissions}
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
                <.link navigate={~p"/screenplay/#{sp.id}?from=dashboard"} class="flex items-center justify-between p-2 rounded-lg hover:bg-gray-50">
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
                  <.link navigate={~p"/screenplay/#{audio.screenplay_id}?from=dashboard"} class="flex items-center justify-between p-2 rounded-lg hover:bg-gray-50">
                    <div class="truncate flex-1 min-w-0">
                      <div class="flex items-center gap-2">
                        <span class="font-medium text-sm text-gray-900 truncate"><%= audio.screenplay.title %></span>
                        <%= if audio.collective_id do %>
                          <span class="px-1.5 py-0.5 text-xs font-medium bg-purple-100 text-purple-700 rounded flex-shrink-0 flex items-center gap-1">
                            <.icon name="hero-user-group" class="w-3 h-3" /> Group
                          </span>
                        <% else %>
                          <span class="px-1.5 py-0.5 text-xs font-medium bg-gray-100 text-gray-600 rounded flex-shrink-0">Solo</span>
                        <% end %>
                      </div>
                      <div class="text-xs text-gray-500"><%= AudioVersion.display_duration(audio) %></div>
                    </div>
                    <div class="flex items-center gap-1 text-gray-400 text-sm flex-shrink-0 ml-2">
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
            <p class="text-gray-500 text-sm">No notifications yet</p>
            <p class="text-xs text-gray-400 mt-1">You'll see updates about your requests, collectives, and commissions here.</p>
          <% else %>
            <div class="space-y-2">
              <%= for n <- Enum.take(@notifications, 5) do %>
                <%= if n.action_url do %>
                  <.link navigate={n.action_url} class={["block p-2 rounded-lg text-sm hover:bg-gray-100 transition", is_nil(n.read_at) && "bg-emerald-50", !is_nil(n.read_at) && "bg-gray-50"]}>
                    <div class="flex items-start gap-2">
                      <div class={["w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5", notification_icon_color(n.type)]}>
                        <.icon name={notification_icon(n.type)} class="w-3 h-3" />
                      </div>
                      <div class="flex-1 min-w-0">
                        <div class="font-medium text-gray-900 truncate"><%= n.title %></div>
                        <%= if n.body do %>
                          <div class="text-xs text-gray-600 truncate"><%= n.body %></div>
                        <% end %>
                        <div class="text-xs text-gray-400 mt-0.5"><%= format_time_ago(n.inserted_at) %></div>
                      </div>
                    </div>
                  </.link>
                <% else %>
                  <div class={["p-2 rounded-lg text-sm", is_nil(n.read_at) && "bg-emerald-50", !is_nil(n.read_at) && "bg-gray-50"]}>
                    <div class="flex items-start gap-2">
                      <div class={["w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5", notification_icon_color(n.type)]}>
                        <.icon name={notification_icon(n.type)} class="w-3 h-3" />
                      </div>
                      <div class="flex-1 min-w-0">
                        <div class="font-medium text-gray-900 truncate"><%= n.title %></div>
                        <%= if n.body do %>
                          <div class="text-xs text-gray-600 truncate"><%= n.body %></div>
                        <% end %>
                        <div class="text-xs text-gray-400 mt-0.5"><%= format_time_ago(n.inserted_at) %></div>
                      </div>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
            <%= if length(@notifications) > 5 do %>
              <button phx-click="change_tab" phx-value-tab="notifications" class="w-full mt-2 text-xs text-center text-emerald-600 hover:underline">
                View all notifications
              </button>
            <% end %>
          <% end %>
        </div>
      </div>

      <!-- Active Commissions Preview -->
      <% active = Enum.filter(@commissions, fn c -> c.status in ["accepted", "in_progress", "submitted"] end) %>
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
                    <%= if @current_user.user_type == "writer", do: "with #{c.performer.name}", else: "for #{c.writer.name}" %>
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
      <!-- Header with Action Buttons -->
      <div class="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3">
        <h2 class="text-lg font-semibold text-gray-900">My Work</h2>
        <div class="flex gap-2">
          <button
            phx-click="toggle_create_project"
            class={[
              "inline-flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition text-sm",
              !@show_create_project && "bg-purple-600 text-white hover:bg-purple-700",
              @show_create_project && "bg-gray-200 text-gray-700 hover:bg-gray-300"
            ]}
          >
            <%= if @show_create_project do %>
              <.icon name="hero-x-mark" class="w-4 h-4" />
              Cancel
            <% else %>
              <.icon name="hero-folder-plus" class="w-4 h-4" />
              New Project
            <% end %>
          </button>
          <button
            phx-click="toggle_upload_form"
            class={[
              "inline-flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition text-sm",
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
      </div>

      <!-- Create Project Form -->
      <%= if @show_create_project do %>
        <div class="bg-purple-50 border border-purple-200 rounded-xl p-4 sm:p-6">
          <h3 class="font-semibold text-gray-900 mb-4">Create New Project</h3>
          <form phx-submit="create_project" class="space-y-4">
            <div class="grid sm:grid-cols-2 gap-4">
              <.styled_input
                name="title"
                label="Title"
                required={true}
                placeholder="Your project title"
              />
              <.styled_dropdown
                name="project_type"
                label="Project Type"
                value="series"
                options={[
                  {"TV Series", "series"},
                  {"Limited Series", "limited_series"},
                  {"Miniseries", "miniseries"},
                  {"Anthology", "anthology"},
                  {"Web Series", "web_series"},
                  {"Feature Film", "feature_film"},
                  {"Documentary Series", "documentary_series"},
                  {"Podcast Drama", "podcast_drama"},
                  {"Short Film Collection", "short_film_collection"}
                ]}
              />
            </div>
            <.styled_dropdown
              name="genre"
              label="Genre"
              required={true}
              options={ScreenplayProject.genres()}
            />
            <.styled_textarea
              name="logline"
              label="Logline"
              required={true}
              rows={2}
              placeholder="A brief summary of your series premise..."
            />
            <button type="submit" class="w-full bg-purple-600 text-white py-3 rounded-xl font-medium hover:bg-purple-700 transition-colors">
              Create Project
            </button>
          </form>
        </div>
      <% end %>

      <!-- Upload Form (Inline) -->
      <%= if @show_upload_form do %>
        <div class="bg-white rounded-xl border p-4 sm:p-6">
          <%= if @upload_error do %>
            <div class="bg-red-50 border border-red-200 rounded-xl p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
              <.icon name="hero-exclamation-circle" class="w-5 h-5" />
              <%= @upload_error %>
            </div>
          <% end %>

          <h3 class="font-semibold text-gray-900 mb-6">Upload New Screenplay</h3>
          <form phx-change="validate_upload" phx-submit="publish_screenplay" class="space-y-5">
            <div class="grid sm:grid-cols-2 gap-4">
              <.styled_input
                name="title"
                value={@upload_title}
                label="Title"
                placeholder="Your screenplay title"
                required={true}
              />
              <.styled_dropdown
                name="genre"
                value={@upload_genre}
                options={Screenplay.genres()}
                label="Genre"
                required={true}
              />
            </div>

            <.styled_textarea
              name="logline"
              value={@upload_logline}
              label="Logline"
              placeholder="One sentence that captures your story..."
              rows={2}
              required={true}
            />

            <div class="grid sm:grid-cols-2 gap-4">
              <.styled_number
                name="page_count"
                value={@upload_page_count}
                label="Page Count"
                placeholder="Number of pages"
                min={1}
                max={500}
              />

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1.5">Script PDF</label>
                <div
                  class="border-2 border-dashed border-gray-200 rounded-xl p-4 text-center cursor-pointer hover:border-emerald-400 hover:bg-emerald-50/50 transition-colors"
                  phx-drop-target={@uploads.pdf.ref}
                >
                  <.live_file_input upload={@uploads.pdf} class="sr-only" />
                  <label for={@uploads.pdf.ref} class="cursor-pointer block">
                    <%= if Enum.empty?(@uploads.pdf.entries) do %>
                      <.icon name="hero-document-text" class="w-8 h-8 text-gray-300 mx-auto mb-2" />
                      <p class="text-sm text-gray-500">Drop PDF or <span class="text-emerald-600 font-medium">browse</span></p>
                    <% else %>
                      <%= for entry <- @uploads.pdf.entries do %>
                        <div class="flex items-center justify-center gap-2">
                          <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-500" />
                          <p class="text-sm text-emerald-600 font-medium truncate"><%= entry.client_name %></p>
                        </div>
                      <% end %>
                    <% end %>
                  </label>
                </div>
              </div>
            </div>

            <!-- Characters Section -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-3">Characters (optional)</label>
              <div class="space-y-3">
                <%= for {char, index} <- Enum.with_index(@upload_characters) do %>
                  <div class="flex flex-col sm:flex-row sm:items-center gap-3 p-3 bg-gray-50 rounded-xl">
                    <div class="flex-1">
                      <input
                        type="text"
                        name={"char_name_#{index}"}
                        value={char.name}
                        phx-blur="update_character"
                        phx-value-index={index}
                        phx-value-field="name"
                        placeholder="Character name"
                        class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500"
                      />
                    </div>
                    <div class="flex items-center gap-2">
                      <div class="flex rounded-lg border border-gray-200 overflow-hidden">
                        <%= for gender <- Character.genders() do %>
                          <button
                            type="button"
                            phx-click="update_character"
                            phx-value-index={index}
                            phx-value-field="gender"
                            phx-value-gender={gender}
                            class={[
                              "px-3 py-2 text-sm font-medium transition-colors",
                              gender == char.gender && "bg-emerald-500 text-white",
                              gender != char.gender && "bg-white text-gray-600 hover:bg-gray-50"
                            ]}
                          >
                            <%= gender %>
                          </button>
                        <% end %>
                      </div>
                      <input
                        type="hidden"
                        name={"char_gender_#{index}"}
                        value={char.gender}
                      />
                      <input
                        type="number"
                        name={"char_lines_#{index}"}
                        value={char.estimated_lines}
                        phx-blur="update_character"
                        phx-value-index={index}
                        phx-value-field="estimated_lines"
                        placeholder="Lines"
                        min="0"
                        class="w-20 px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                      />
                      <button
                        type="button"
                        phx-click="remove_character"
                        phx-value-index={index}
                        class="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                      >
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                <% end %>

                <button
                  type="button"
                  phx-click="add_character"
                  class="w-full border-2 border-dashed border-gray-200 rounded-xl py-3 text-gray-500 hover:border-emerald-400 hover:text-emerald-600 hover:bg-emerald-50/50 text-sm font-medium transition-colors"
                >
                  + Add Character
                </button>
              </div>
            </div>

            <button type="submit" class="w-full bg-emerald-600 text-white py-3 rounded-xl font-medium hover:bg-emerald-700 transition-colors shadow-sm">
              Publish Screenplay
            </button>
          </form>
        </div>
      <% end %>

      <!-- Projects List -->
      <%= if length(@projects) > 0 do %>
        <div class="space-y-3">
          <h3 class="text-sm font-medium text-gray-500 uppercase tracking-wider">Projects</h3>
          <%= for project <- @projects do %>
            <.link navigate={~p"/project/#{project.id}"} class="block bg-white rounded-xl border hover:border-purple-300 hover:shadow-sm transition p-4">
              <div class="flex items-start justify-between">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-1">
                    <h4 class="font-semibold text-gray-900 truncate"><%= project.title %></h4>
                    <span class={"px-2 py-0.5 rounded-full text-xs font-medium #{project_type_badge_color(project.project_type)}"}>
                      <%= String.capitalize(project.project_type) %>
                    </span>
                    <.genre_badge genre={project.genre} />
                  </div>
                  <p class="text-sm text-gray-600 line-clamp-2"><%= project.logline %></p>
                </div>
                <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400 flex-shrink-0 ml-2" />
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>

      <!-- Standalone Screenplays List -->
      <%= if Enum.empty?(@screenplays) && Enum.empty?(@projects) && !@show_upload_form && !@show_create_project do %>
        <div class="bg-white rounded-xl border p-8 text-center">
          <.icon name="hero-document-text" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <h3 class="font-semibold text-gray-900 mb-2">No work yet</h3>
          <p class="text-gray-600 mb-4">Create a project or upload a standalone screenplay to get started</p>
        </div>
      <% else %>
        <%= if length(@screenplays) > 0 do %>
          <div class="space-y-3">
            <%= if length(@projects) > 0 do %>
              <h3 class="text-sm font-medium text-gray-500 uppercase tracking-wider mt-6">Standalone Scripts</h3>
            <% end %>
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
                      <div class="flex items-center justify-between mb-4">
                        <h3 class="font-semibold text-gray-900">Edit Screenplay</h3>
                        <button type="button" phx-click="cancel_edit" class="p-1.5 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors">
                          <.icon name="hero-x-mark" class="w-5 h-5" />
                        </button>
                      </div>

                      <.styled_input
                        name="title"
                        value={@edit_title}
                        label="Title"
                        required={true}
                      />

                      <.styled_dropdown
                        name="genre"
                        value={@edit_genre}
                        options={Screenplay.genres()}
                        label="Genre"
                        required={true}
                      />

                      <.styled_textarea
                        name="logline"
                        value={@edit_logline}
                        label="Logline"
                        rows={2}
                        required={true}
                      />

                      <!-- Replace Script PDF -->
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1.5">
                          Replace Script (Optional)
                        </label>
                        <div
                          class="border-2 border-dashed border-gray-200 rounded-xl p-4 text-center cursor-pointer hover:border-emerald-400 hover:bg-emerald-50/50 transition-colors"
                          phx-drop-target={@uploads.replace_pdf.ref}
                        >
                          <.live_file_input upload={@uploads.replace_pdf} class="sr-only" />
                          <label for={@uploads.replace_pdf.ref} class="cursor-pointer block">
                            <.icon name="hero-document-text" class="w-8 h-8 mx-auto mb-2 text-gray-300" />
                            <p class="text-sm text-gray-500">
                              <%= if sp.pdf_url do %>
                                Upload new PDF to replace current script
                              <% else %>
                                Upload PDF script
                              <% end %>
                            </p>
                          </label>
                          <%= for entry <- @uploads.replace_pdf.entries do %>
                            <div class="mt-3 flex items-center justify-center gap-2">
                              <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-500" />
                              <p class="text-sm text-emerald-600 font-medium"><%= entry.client_name %></p>
                            </div>
                          <% end %>
                        </div>
                        <%= if sp.pdf_url do %>
                          <p class="text-xs text-gray-500 mt-2">
                            Current: v<%= sp.version || 1 %> · Uploading new script will create v<%= (sp.version || 1) + 1 %>
                          </p>
                        <% end %>
                      </div>

                      <%= if (sp.audio_version_count || 0) > 0 do %>
                        <div class="bg-amber-50 border border-amber-200 rounded-xl p-3 text-sm text-amber-800 flex items-start gap-2">
                          <.icon name="hero-exclamation-triangle" class="w-5 h-5 flex-shrink-0" />
                          <span>
                            This screenplay has <%= sp.audio_version_count %> audio recording<%= if sp.audio_version_count != 1, do: "s" %>.
                            Performers will be notified of updates.
                          </span>
                        </div>
                      <% end %>

                      <div class="flex gap-3">
                        <button
                          type="button"
                          phx-click="cancel_edit"
                          class="flex-1 px-4 py-2.5 border border-gray-200 rounded-xl text-gray-700 hover:bg-gray-50 font-medium transition-colors"
                        >
                          Cancel
                        </button>
                        <button
                          type="submit"
                          class="flex-1 px-4 py-2.5 bg-emerald-600 text-white rounded-xl hover:bg-emerald-700 font-medium transition-colors shadow-sm"
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
                      <.link navigate={~p"/screenplay/#{sp.id}?from=dashboard"} class="flex-1 min-w-0">
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
      <% end %>
    </div>
    """
  end

  defp project_type_badge_color("series"), do: "bg-blue-100 text-blue-700"
  defp project_type_badge_color("limited_series"), do: "bg-indigo-100 text-indigo-700"
  defp project_type_badge_color("anthology"), do: "bg-purple-100 text-purple-700"
  defp project_type_badge_color("miniseries"), do: "bg-amber-100 text-amber-700"
  defp project_type_badge_color("web_series"), do: "bg-cyan-100 text-cyan-700"
  defp project_type_badge_color("feature_film"), do: "bg-rose-100 text-rose-700"
  defp project_type_badge_color("documentary_series"), do: "bg-teal-100 text-teal-700"
  defp project_type_badge_color("podcast_drama"), do: "bg-orange-100 text-orange-700"
  defp project_type_badge_color("short_film_collection"), do: "bg-pink-100 text-pink-700"
  defp project_type_badge_color(_), do: "bg-gray-100 text-gray-700"

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
            <.link navigate={~p"/screenplay/#{audio.screenplay_id}?from=dashboard"} class={["block bg-white rounded-xl border p-4 transition", is_outdated && "border-amber-300", !is_outdated && "hover:border-emerald-300"]}>
              <div class="flex items-center justify-between">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 flex-wrap">
                    <h3 class="font-semibold text-gray-900 truncate"><%= audio.screenplay.title %></h3>
                    <%= if audio.collective_id && audio.collective do %>
                      <span class="px-2 py-0.5 text-xs font-medium bg-purple-100 text-purple-700 rounded-full flex items-center gap-1">
                        <.icon name="hero-user-group" class="w-3 h-3" />
                        <%= audio.collective.name %>
                      </span>
                    <% else %>
                      <span class="px-2 py-0.5 text-xs font-medium bg-gray-100 text-gray-600 rounded-full">Solo</span>
                    <% end %>
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
  # Collectives Tab (Performers)
  # ===========================================================================

  defp collectives_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <h2 class="text-lg font-semibold text-gray-900">Collectives</h2>
        <button
          phx-click="toggle_create_collective"
          class={[
            "inline-flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition",
            !@show_create_collective && "bg-emerald-600 text-white hover:bg-emerald-700",
            @show_create_collective && "bg-gray-200 text-gray-700 hover:bg-gray-300"
          ]}
        >
          <%= if @show_create_collective do %>
            <.icon name="hero-x-mark" class="w-4 h-4" />
            Cancel
          <% else %>
            <.icon name="hero-plus" class="w-4 h-4" />
            Create
          <% end %>
        </button>
      </div>

      <!-- Create Collective Form -->
      <%= if @show_create_collective do %>
        <div class="bg-white rounded-xl border p-4 sm:p-6">
          <h3 class="font-semibold text-gray-900 mb-4">Create a Collective</h3>
          <form phx-change="validate_collective" phx-submit="create_collective" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Collective Name *</label>
              <input
                type="text"
                name="name"
                value={@new_collective_name}
                class="w-full border rounded-lg px-3 py-2.5 focus:border-emerald-500 focus:ring-emerald-500"
                placeholder="e.g., The Voice Actors Guild"
                required
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Bio</label>
              <textarea
                name="bio"
                rows="3"
                class="w-full border rounded-lg px-3 py-2.5 focus:border-emerald-500 focus:ring-emerald-500"
                placeholder="Tell people what your collective specializes in..."
              ><%= @new_collective_bio %></textarea>
            </div>
            <p class="text-sm text-gray-500">
              You'll be the admin of this collective. After creating, you can invite other voice artists to join.
            </p>
            <button type="submit" class="w-full bg-emerald-600 text-white py-2.5 rounded-lg font-medium hover:bg-emerald-700 transition">
              Create Collective
            </button>
          </form>
        </div>
      <% end %>

      <!-- Pending Invitations -->
      <%= if length(@pending_invitations) > 0 do %>
        <div class="bg-amber-50 border border-amber-200 rounded-xl p-4">
          <div class="flex items-center gap-2 mb-3">
            <.icon name="hero-envelope" class="w-5 h-5 text-amber-600" />
            <h3 class="font-semibold text-amber-900">Pending Invitations (<%= length(@pending_invitations) %>)</h3>
          </div>
          <div class="space-y-3">
            <%= for invitation <- @pending_invitations do %>
              <div class="bg-white rounded-lg p-4 border border-amber-200">
                <div class="flex items-start justify-between gap-4">
                  <div class="flex-1">
                    <h4 class="font-semibold text-gray-900"><%= invitation.collective.name %></h4>
                    <p class="text-sm text-gray-600">
                      Invited by <%= invitation.inviter.name %>
                    </p>
                    <%= if invitation.message do %>
                      <p class="text-sm text-gray-700 mt-2 italic">"<%= invitation.message %>"</p>
                    <% end %>
                    <p class="text-xs text-gray-500 mt-2">
                      Expires <%= format_time_ago(invitation.expires_at) %>
                    </p>
                  </div>
                </div>
                <div class="flex gap-2 mt-3">
                  <button
                    phx-click="decline_invitation"
                    phx-value-id={invitation.id}
                    class="flex-1 px-3 py-2 border border-gray-200 rounded-lg text-gray-700 hover:bg-gray-50 text-sm font-medium"
                  >
                    Decline
                  </button>
                  <button
                    phx-click="accept_invitation"
                    phx-value-id={invitation.id}
                    class="flex-1 px-3 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 text-sm font-medium"
                  >
                    Accept & Join
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- My Collectives -->
      <div class="space-y-3">
        <h3 class="font-medium text-gray-700">My Collectives</h3>
        <%= if Enum.empty?(@memberships) do %>
          <div class="bg-white rounded-xl border p-6 text-center">
            <.icon name="hero-user-group" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <h4 class="font-semibold text-gray-900 mb-2">No collectives yet</h4>
            <p class="text-gray-600 text-sm mb-4">
              Create a collective to collaborate with other voice artists, or wait for an invitation.
            </p>
          </div>
        <% else %>
          <%= for membership <- @memberships do %>
            <div class="bg-white rounded-xl border p-4 hover:border-emerald-300 transition">
              <div class="flex items-start justify-between">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-1">
                    <%= if membership.role == "admin" do %>
                      <.icon name="hero-star" class="w-4 h-4 text-amber-500" />
                    <% end %>
                    <h4 class="font-semibold text-gray-900 truncate"><%= membership.collective.name %></h4>
                  </div>
                  <p class="text-sm text-gray-500">
                    <%= String.capitalize(membership.role) %> ·
                    <%= length(membership.collective.memberships) %> member<%= if length(membership.collective.memberships) != 1, do: "s" %>
                  </p>
                  <p class="text-xs text-gray-400 mt-1">
                    Joined <%= Calendar.strftime(membership.joined_at, "%b %d, %Y") %>
                  </p>
                </div>
                <div class="flex items-center gap-2 ml-3 flex-shrink-0">
                  <%= if membership.role == "admin" do %>
                    <.link
                      navigate={~p"/collective/#{membership.collective.slug}/settings"}
                      class="p-2 text-emerald-600 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition"
                      title="Settings"
                    >
                      <.icon name="hero-cog-6-tooth" class="w-5 h-5" />
                    </.link>
                  <% else %>
                    <button
                      phx-click="leave_collective"
                      phx-value-id={membership.collective.id}
                      data-confirm="Are you sure you want to leave this collective?"
                      class="p-2 text-red-600 bg-red-50 hover:bg-red-100 rounded-lg transition"
                      title="Leave collective"
                    >
                      <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" />
                    </button>
                  <% end %>
                  <.link
                    navigate={~p"/collective/#{membership.collective.slug}"}
                    class="p-2 text-gray-600 bg-gray-50 hover:bg-gray-100 rounded-lg transition"
                    title="View profile"
                  >
                    <.icon name="hero-eye" class="w-5 h-5" />
                  </.link>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>

      <!-- Pending Join Requests -->
      <%= if length(@pending_join_requests) > 0 do %>
        <div class="space-y-3">
          <h3 class="font-medium text-gray-700">Your Join Requests</h3>
          <%= for request <- @pending_join_requests do %>
            <div class="bg-white rounded-xl border p-4">
              <div class="flex items-center justify-between">
                <div class="flex-1 min-w-0">
                  <.link navigate={~p"/collective/#{request.collective.slug}"} class="font-semibold text-gray-900 hover:text-emerald-600">
                    <%= request.collective.name %>
                  </.link>
                  <p class="text-xs text-gray-500">
                    Requested <%= format_time_ago(request.inserted_at) %>
                  </p>
                </div>
                <div class="flex items-center gap-2 flex-shrink-0">
                  <span class="px-2 py-1 text-xs font-medium bg-amber-100 text-amber-700 rounded-full">
                    Pending
                  </span>
                  <button
                    phx-click="cancel_join_request"
                    phx-value-id={request.id}
                    class="text-sm text-red-600 hover:text-red-700"
                  >
                    Cancel
                  </button>
                </div>
              </div>

              <!-- Full conversation thread -->
              <% messages = request.messages || [] %>
              <%= if (request.message && request.message != "") || length(messages) > 0 do %>
                <div class="mt-3 space-y-2 max-h-40 overflow-y-auto">
                  <!-- Your initial message -->
                  <%= if request.message && request.message != "" do %>
                    <div class="p-3 bg-gray-50 rounded-lg">
                      <p class="text-xs text-gray-500 mb-1">You:</p>
                      <p class="text-sm text-gray-700">"<%= request.message %>"</p>
                    </div>
                  <% end %>
                  <!-- Conversation messages -->
                  <%= for msg <- messages do %>
                    <% is_my_msg = msg.sender_id == @current_user.id %>
                    <div class={[
                      "p-3 rounded-lg",
                      is_my_msg && "bg-gray-50",
                      !is_my_msg && "bg-blue-50 border-l-2 border-blue-400"
                    ]}>
                      <p class={["text-xs mb-1", is_my_msg && "text-gray-500", !is_my_msg && "text-blue-600"]}>
                        <%= if is_my_msg, do: "You:", else: "Collective:" %>
                      </p>
                      <p class="text-sm text-gray-700">"<%= msg.content %>"</p>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <!-- Reply input -->
              <form phx-submit="send_request_message" class="mt-3">
                <input type="hidden" name="request_id" value={request.id} />
                <div class="flex gap-2">
                  <input
                    type="text"
                    name="content"
                    placeholder="Reply to collective..."
                    class="flex-1 text-sm border border-gray-200 rounded-lg px-3 py-2 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                    required
                  />
                  <button type="submit" class="px-3 py-2 bg-emerald-100 text-emerald-700 rounded-lg hover:bg-emerald-200 transition">
                    <.icon name="hero-paper-airplane" class="w-4 h-4" />
                  </button>
                </div>
              </form>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Rejected Join Requests -->
      <%= if length(@rejected_join_requests) > 0 do %>
        <div class="space-y-3">
          <h3 class="font-medium text-gray-700">Declined Requests</h3>
          <%= for request <- @rejected_join_requests do %>
            <div class="bg-red-50 border border-red-200 rounded-xl p-4">
              <div class="flex items-start justify-between">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <h4 class="font-semibold text-gray-900"><%= request.collective.name %></h4>
                    <span class="px-2 py-0.5 text-xs font-medium bg-red-100 text-red-700 rounded-full">
                      Declined
                    </span>
                  </div>
                  <%= if request.response_message && request.response_message != "" do %>
                    <p class="text-sm text-gray-700 mt-1 italic">"<%= request.response_message %>"</p>
                  <% end %>
                  <p class="text-xs text-gray-500 mt-1">
                    Reviewed <%= format_time_ago(request.reviewed_at || request.updated_at) %>
                  </p>
                </div>
                <.link
                  navigate={~p"/collective/#{request.collective.slug}"}
                  class="text-sm text-emerald-600 hover:text-emerald-700 font-medium whitespace-nowrap ml-3"
                >
                  Request Again
                </.link>
              </div>
            </div>
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
    all_commissions = assigns.commissions

    # Calculate counts for each filter
    active_count = Enum.count(all_commissions, & &1.status in ["accepted", "in_progress", "submitted", "revision_requested"])
    pending_count = Enum.count(all_commissions, & &1.status == "pending")
    completed_count = Enum.count(all_commissions, & &1.status == "completed")
    cancelled_count = Enum.count(all_commissions, & &1.status in ["cancelled", "declined"])

    filtered = case assigns.filter do
      "all" -> all_commissions
      "active" -> Enum.filter(all_commissions, & &1.status in ["accepted", "in_progress", "submitted", "revision_requested"])
      "pending" -> Enum.filter(all_commissions, & &1.status == "pending")
      "completed" -> Enum.filter(all_commissions, & &1.status == "completed")
      "cancelled" -> Enum.filter(all_commissions, & &1.status in ["cancelled", "declined"])
      _ -> all_commissions
    end

    assigns = assign(assigns, :filtered_commissions, filtered)
    assigns = assign(assigns, :all_commissions, all_commissions)
    assigns = assign(assigns, :active_count, active_count)
    assigns = assign(assigns, :pending_count, pending_count)
    assigns = assign(assigns, :completed_count, completed_count)
    assigns = assign(assigns, :cancelled_count, cancelled_count)

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-gray-900">Commissions</h2>
      </div>

      <!-- Filter Pills -->
      <div class="flex gap-2 overflow-x-auto pb-2 -mx-4 px-4 sm:mx-0 sm:px-0">
        <% filter_counts = %{"all" => length(@all_commissions), "active" => @active_count, "pending" => @pending_count, "completed" => @completed_count, "cancelled" => @cancelled_count} %>
        <%= for {filter, label} <- [{"all", "All"}, {"active", "Active"}, {"pending", "Pending"}, {"completed", "Completed"}, {"cancelled", "Cancelled"}] do %>
          <% count = Map.get(filter_counts, filter, 0) %>
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
            <%= if count > 0 do %>
              (<%= count %>)
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
                    <%= if @current_user.user_type == "writer" do %>
                      with <%= c.performer.name %>
                    <% else %>
                      for <%= c.writer.name %>
                    <% end %>
                  </div>
                  <div class="text-sm text-gray-500 mt-1">
                    <%= format_money(c.agreed_amount_cents || c.offered_amount_cents) %>
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

  defp format_time_ago(nil), do: ""
  defp format_time_ago(%NaiveDateTime{} = naive) do
    datetime = DateTime.from_naive!(naive, "Etc/UTC")
    format_time_ago(datetime)
  end
  defp format_time_ago(%DateTime{} = datetime) do
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

  # Notification type to icon mapping
  defp notification_icon(type) do
    case type do
      # Commissions
      "commission_request_received" -> "hero-clipboard-document-list"
      "commission_accepted" -> "hero-check-circle"
      "commission_declined" -> "hero-x-circle"
      "submission_received" -> "hero-microphone"
      "revision_requested" -> "hero-arrow-path"
      "commission_completed" -> "hero-trophy"
      "commission_cancelled" -> "hero-x-mark"
      "message_received" -> "hero-chat-bubble-left"
      "payment_released" -> "hero-banknotes"
      # Collectives
      "collective_invitation" -> "hero-envelope"
      "collective_member_joined" -> "hero-user-plus"
      "collective_invitation_declined" -> "hero-user-minus"
      "collective_join_request" -> "hero-hand-raised"
      "collective_request_approved" -> "hero-check-badge"
      "collective_request_rejected" -> "hero-x-circle"
      "collective_removed" -> "hero-user-minus"
      "collective_request_note" -> "hero-chat-bubble-left-ellipsis"
      # Screenplays
      "screenplay_updated" -> "hero-document-text"
      "screenplay_deleted" -> "hero-trash"
      # Default
      _ -> "hero-bell"
    end
  end

  # Notification type to color mapping
  defp notification_icon_color(type) do
    case type do
      # Success/positive
      "commission_accepted" -> "bg-green-100 text-green-600"
      "commission_completed" -> "bg-green-100 text-green-600"
      "collective_request_approved" -> "bg-green-100 text-green-600"
      "collective_member_joined" -> "bg-green-100 text-green-600"
      "payment_released" -> "bg-green-100 text-green-600"
      # Negative
      "commission_declined" -> "bg-red-100 text-red-600"
      "commission_cancelled" -> "bg-red-100 text-red-600"
      "collective_request_rejected" -> "bg-red-100 text-red-600"
      "collective_removed" -> "bg-red-100 text-red-600"
      "collective_invitation_declined" -> "bg-red-100 text-red-600"
      "screenplay_deleted" -> "bg-red-100 text-red-600"
      # Action needed
      "commission_request_received" -> "bg-blue-100 text-blue-600"
      "submission_received" -> "bg-blue-100 text-blue-600"
      "collective_join_request" -> "bg-blue-100 text-blue-600"
      "revision_requested" -> "bg-amber-100 text-amber-600"
      # Messages/invitations
      "collective_invitation" -> "bg-purple-100 text-purple-600"
      "message_received" -> "bg-purple-100 text-purple-600"
      "collective_request_note" -> "bg-purple-100 text-purple-600"
      # Default
      _ -> "bg-gray-100 text-gray-600"
    end
  end
end
