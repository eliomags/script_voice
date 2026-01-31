defmodule ScriptVoiceWeb.VerifyLive do
  @moduledoc """
  Verification LiveView - Handles user verification via phone or email.

  Supports both phone (SMS) and email verification.
  Writers and voice artists also need video verification.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Accounts
  alias ScriptVoice.Accounts.User

  @verification_phrases [
    "The quick brown fox jumps over the lazy dog",
    "Pack my box with five dozen liquor jugs",
    "How vexingly quick daft zebras jump",
    "The five boxing wizards jump quickly",
    "Sphinx of black quartz judge my vow"
  ]

  @impl true
  def mount(params, session, socket) do
    current_user = get_current_user(session)

    # Redirect if already verified
    if current_user && User.verified?(current_user) do
      {:ok, push_navigate(socket, to: ~p"/browse")}
    else
      user_type = Map.get(params, "type", "visitor")

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:user_type, user_type)
       |> assign(:page_title, "Verify Your Account")
       |> assign(:step, :contact_info)
       |> assign(:verify_method, nil)
       |> assign(:code_sent, false)
       |> assign(:code_verified, false)
       |> assign(:video_recorded, false)
       |> assign(:video_state, :idle)
       |> assign(:video_data, nil)
       |> assign(:performer_type, "solo")
       |> assign(:verification_phrase, Enum.random(@verification_phrases))
       |> assign(:form_data, %{
         name: "",
         email: "",
         phone: "",
         social_link: ""
       })
       |> assign(:error, nil)
       |> assign(:submitted_code, "")}
    end
  end

  @impl true
  def handle_event("select_user_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :user_type, type)}
  end

  @impl true
  def handle_event("update_form", %{"field" => field, "value" => value}, socket) do
    form_data = Map.put(socket.assigns.form_data, String.to_atom(field), value)
    {:noreply, assign(socket, :form_data, form_data)}
  end

  @impl true
  def handle_event("focus_verify_method", %{"method" => method}, socket) do
    if socket.assigns.code_verified do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :verify_method, method)}
    end
  end

  @impl true
  def handle_event("send_code", _, socket) do
    method = socket.assigns.verify_method
    form_data = socket.assigns.form_data

    target = if method == "phone", do: form_data.phone, else: form_data.email

    if target == "" do
      {:noreply, assign(socket, :error, "Please enter your #{method}")}
    else
      # In production, this would actually send the code
      user_id = if socket.assigns.current_user, do: socket.assigns.current_user.id, else: nil
      Accounts.create_verification_code(user_id, method, target)

      {:noreply,
       socket
       |> assign(:code_sent, true)
       |> assign(:error, nil)}
    end
  end

  @impl true
  def handle_event("verify_code", %{"code" => code}, socket) do
    method = socket.assigns.verify_method
    form_data = socket.assigns.form_data
    target = if method == "phone", do: form_data.phone, else: form_data.email

    case Accounts.verify_code(target, method, code) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:code_verified, true)
         |> assign(:error, nil)}

      {:error, :invalid_code} ->
        {:noreply, assign(socket, :error, "Invalid code. Please try again.")}

      {:error, :code_not_found} ->
        {:noreply, assign(socket, :error, "Code expired. Please request a new one.")}

      {:error, :too_many_attempts} ->
        {:noreply, assign(socket, :error, "Too many attempts. Please request a new code.")}
    end
  end

  @impl true
  def handle_event("update_code", %{"value" => value}, socket) do
    {:noreply, assign(socket, :submitted_code, value)}
  end

  @impl true
  def handle_event("resend_code", _, socket) do
    {:noreply,
     socket
     |> assign(:code_sent, false)
     |> assign(:error, nil)}
  end

  # Video recording events from the VideoRecorder hook
  @impl true
  def handle_event("preview_started", _, socket) do
    {:noreply, assign(socket, :video_state, :previewing)}
  end

  @impl true
  def handle_event("recording_started", _, socket) do
    {:noreply, assign(socket, :video_state, :recording)}
  end

  @impl true
  def handle_event("recording_complete", _, socket) do
    {:noreply, assign(socket, :video_state, :recorded)}
  end

  @impl true
  def handle_event("retake", _, socket) do
    {:noreply,
     socket
     |> assign(:video_state, :idle)
     |> assign(:video_recorded, false)}
  end

  @impl true
  def handle_event("video_confirmed", %{"video_data" => video_data, "size" => size}, socket) do
    # Store video data for upload during registration
    {:noreply,
     socket
     |> assign(:video_recorded, true)
     |> assign(:video_data, video_data)
     |> assign(:video_size, size)}
  end

  @impl true
  def handle_event("video_error", %{"message" => message}, socket) do
    {:noreply, assign(socket, :error, message)}
  end

  @impl true
  def handle_event("rerecord_video", _, socket) do
    {:noreply,
     socket
     |> assign(:video_recorded, false)
     |> assign(:video_state, :idle)
     |> assign(:video_data, nil)}
  end

  @impl true
  def handle_event("select_performer_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :performer_type, type)}
  end

  @impl true
  def handle_event("complete_verification", _, socket) do
    form_data = socket.assigns.form_data
    user_type = socket.assigns.user_type

    # Create or update user
    user_attrs = %{
      name: form_data.name,
      email: if(form_data.email != "", do: form_data.email, else: nil),
      phone: if(form_data.phone != "", do: form_data.phone, else: nil),
      user_type: user_type,
      verification_status: "verified",
      verified_via: socket.assigns.verify_method,
      verified_at: DateTime.utc_now(),
      social_links: if(form_data.social_link != "", do: [form_data.social_link], else: [])
    }

    # Add performer type for voice artists
    user_attrs =
      if user_type == "voice_artist" do
        Map.put(user_attrs, :performer_type, socket.assigns.performer_type)
      else
        user_attrs
      end

    case socket.assigns.current_user do
      nil ->
        # Register new user
        case Accounts.register_user(user_attrs) do
          {:ok, user} ->
            {:noreply,
             socket
             |> redirect(to: ~p"/session/login/#{user.id}")}

          {:error, changeset} ->
            {:noreply, assign(socket, :error, format_errors(changeset))}
        end

      user ->
        # Update existing user
        case Accounts.complete_verification(user, %{
               verified_via: socket.assigns.verify_method,
               video_url: nil
             }) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Verification complete!")
             |> push_navigate(to: ~p"/browse")}

          {:error, _} ->
            {:noreply, assign(socket, :error, "Failed to complete verification")}
        end
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> Accounts.get_user(user_id)
    end
  end

  defp needs_video?(user_type) do
    user_type in ["writer", "voice_artist"]
  end

  defp can_complete?(assigns) do
    assigns.code_verified and
      (not needs_video?(assigns.user_type) or assigns.video_recorded) and
      assigns.form_data.name != ""
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8 px-4 sm:px-6">
      <div class="max-w-md mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <div class="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <.icon name="hero-user-circle" class="w-8 h-8 text-emerald-600" />
          </div>
          <h1 class="text-2xl font-bold">
            <%= if @user_type == "visitor", do: "Quick Verification", else: "Verify You're Human" %>
          </h1>
          <p class="text-gray-600 mt-2">
            <%= if @user_type == "visitor" do %>
              Verify to like screenplays and audio performances
            <% else %>
              Quick verification keeps the platform authentic
            <% end %>
          </p>
        </div>

        <!-- Verification Card -->
        <div class="bg-white rounded-2xl shadow-sm border p-6">
          <!-- User Type Selection - Always visible for switching -->
          <div class="mb-6 pb-6 border-b">
            <p class="text-sm font-medium text-gray-700 mb-3">I want to:</p>
            <div class="grid grid-cols-3 gap-2">
              <button
                phx-click="select_user_type"
                phx-value-type="visitor"
                class={[
                  "border-2 rounded-lg p-3 text-center transition touch-manipulation",
                  @user_type == "visitor" && "border-emerald-500 bg-emerald-50",
                  @user_type != "visitor" && "border-gray-200 hover:border-gray-300"
                ]}
              >
                <.icon name="hero-eye" class={["w-6 h-6 mx-auto mb-1", @user_type == "visitor" && "text-emerald-600", @user_type != "visitor" && "text-gray-600"]} />
                <p class="text-xs font-medium">Browse</p>
              </button>
              <button
                phx-click="select_user_type"
                phx-value-type="writer"
                class={[
                  "border-2 rounded-lg p-3 text-center transition touch-manipulation",
                  @user_type == "writer" && "border-emerald-500 bg-emerald-50",
                  @user_type != "writer" && "border-gray-200 hover:border-gray-300"
                ]}
              >
                <.icon name="hero-document-text" class={["w-6 h-6 mx-auto mb-1", @user_type == "writer" && "text-emerald-600", @user_type != "writer" && "text-gray-600"]} />
                <p class="text-xs font-medium">Write</p>
              </button>
              <button
                phx-click="select_user_type"
                phx-value-type="voice_artist"
                class={[
                  "border-2 rounded-lg p-3 text-center transition touch-manipulation",
                  @user_type == "voice_artist" && "border-emerald-500 bg-emerald-50",
                  @user_type != "voice_artist" && "border-gray-200 hover:border-gray-300"
                ]}
              >
                <.icon name="hero-microphone" class={["w-6 h-6 mx-auto mb-1", @user_type == "voice_artist" && "text-emerald-600", @user_type != "voice_artist" && "text-gray-600"]} />
                <p class="text-xs font-medium">Perform</p>
              </button>
            </div>
          </div>

          <!-- Error Display -->
          <%= if @error do %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
              <.icon name="hero-exclamation-circle" class="w-5 h-5" />
              <%= @error %>
            </div>
          <% end %>

          <!-- Name Input -->
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 mb-1">Your Name *</label>
            <input
              type="text"
              value={@form_data.name}
              phx-blur="update_form"
              phx-value-field="name"
              class="w-full border rounded-lg px-3 py-2.5 focus:border-emerald-500 focus:ring-emerald-500"
              placeholder="Enter your name"
            />
          </div>

          <!-- Contact Information -->
          <div class="mb-4">
            <p class="text-sm font-medium text-gray-700 mb-2">Contact Information</p>
            <p class="text-xs text-gray-500 mb-3">
              Choose phone or email for verification. You can add both and update later.
            </p>

            <div class="grid grid-cols-2 gap-3 mb-3">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Phone</label>
                <input
                  type="tel"
                  value={@form_data.phone}
                  phx-blur="update_form"
                  phx-value-field="phone"
                  phx-focus="focus_verify_method"
                  phx-value-method="phone"
                  disabled={@code_verified}
                  class={[
                    "w-full border rounded-lg px-3 py-2.5 text-sm",
                    "focus:border-emerald-500 focus:ring-emerald-500",
                    @verify_method == "phone" && !@code_verified && "border-emerald-500 ring-1 ring-emerald-500",
                    @code_verified && "bg-gray-50"
                  ]}
                  placeholder="+1 (555) 000-0000"
                />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Email</label>
                <input
                  type="email"
                  value={@form_data.email}
                  phx-blur="update_form"
                  phx-value-field="email"
                  phx-focus="focus_verify_method"
                  phx-value-method="email"
                  disabled={@code_verified}
                  class={[
                    "w-full border rounded-lg px-3 py-2.5 text-sm",
                    "focus:border-emerald-500 focus:ring-emerald-500",
                    @verify_method == "email" && !@code_verified && "border-emerald-500 ring-1 ring-emerald-500",
                    @code_verified && "bg-gray-50"
                  ]}
                  placeholder="your@email.com"
                />
              </div>
            </div>

            <!-- Verification Code Section -->
            <%= if @verify_method && !@code_verified do %>
              <div class="bg-gray-50 rounded-lg p-3">
                <%= if !@code_sent do %>
                  <div class="flex items-center justify-between">
                    <p class="text-sm text-gray-600">
                      Verify via <span class="font-medium"><%= if @verify_method == "phone", do: "SMS", else: "email" %></span>
                    </p>
                    <.button phx-click="send_code" size="sm">
                      Send Code
                    </.button>
                  </div>
                <% else %>
                  <div class="space-y-2">
                    <p class="text-sm text-gray-600">
                      Enter the 6-digit code sent to your <%= @verify_method %>:
                    </p>
                    <div class="flex gap-2">
                      <input
                        type="text"
                        maxlength="6"
                        value={@submitted_code}
                        phx-keyup="update_code"
                        phx-key="*"
                        class="flex-1 border rounded-lg px-3 py-2 text-center tracking-widest font-mono focus:border-emerald-500 focus:ring-emerald-500"
                        placeholder="000000"
                      />
                      <.button phx-click="verify_code" phx-value-code={@submitted_code} size="sm">
                        Verify
                      </.button>
                    </div>
                    <button phx-click="resend_code" class="text-xs text-gray-500 underline">
                      Use different <%= if @verify_method == "phone", do: "number", else: "email" %>
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>

            <%= if @code_verified do %>
              <div class="flex items-center gap-2 text-emerald-600 bg-emerald-50 rounded-lg p-2">
                <.icon name="hero-check-circle" class="w-4 h-4" />
                <span class="text-sm font-medium">
                  <%= if @verify_method == "phone", do: "Phone", else: "Email" %> verified!
                </span>
              </div>
            <% end %>
          </div>

          <!-- Voice Artist: Performer Type -->
          <%= if @user_type == "voice_artist" do %>
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-2">Profile Type *</label>
              <div class="grid grid-cols-2 gap-3">
                <button
                  phx-click="select_performer_type"
                  phx-value-type="solo"
                  class={[
                    "border-2 rounded-lg p-3 text-center transition touch-manipulation",
                    @performer_type == "solo" && "border-emerald-500 bg-emerald-50",
                    @performer_type != "solo" && "border-gray-200 hover:border-gray-300"
                  ]}
                >
                  <.icon name="hero-user" class="w-6 h-6 mx-auto mb-1 text-emerald-600" />
                  <p class="font-medium text-sm">Solo Artist</p>
                </button>
                <button
                  phx-click="select_performer_type"
                  phx-value-type="group"
                  class={[
                    "border-2 rounded-lg p-3 text-center transition touch-manipulation",
                    @performer_type == "group" && "border-emerald-500 bg-emerald-50",
                    @performer_type != "group" && "border-gray-200 hover:border-gray-300"
                  ]}
                >
                  <.icon name="hero-users" class="w-6 h-6 mx-auto mb-1 text-gray-600" />
                  <p class="font-medium text-sm">Group/Ensemble</p>
                </button>
              </div>
            </div>
          <% end %>

          <!-- Video Verification (for writers and voice artists) -->
          <%= if needs_video?(@user_type) do %>
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-2">Video Verification *</label>

              <!-- Phrase to read -->
              <div class="bg-gray-50 rounded-lg p-3 mb-3">
                <p class="text-xs text-gray-500 mb-1">Read this phrase aloud:</p>
                <p class="font-mono text-sm font-medium text-gray-800">
                  "<%= @verification_phrase %>"
                </p>
              </div>

              <!-- Video Recorder -->
              <div
                id="video-recorder"
                phx-hook="VideoRecorder"
                class={[
                  "border-2 rounded-lg overflow-hidden",
                  @video_recorded && "border-emerald-500",
                  !@video_recorded && "border-dashed border-gray-300"
                ]}
              >
                <%= if @video_recorded do %>
                  <!-- Recording Complete -->
                  <div class="p-6 text-center bg-emerald-50">
                    <.icon name="hero-check-circle" class="w-10 h-10 mx-auto mb-2 text-emerald-600" />
                    <p class="text-sm text-emerald-700 font-medium mb-1">Video recorded successfully!</p>
                    <p class="text-xs text-gray-500 mb-3">Your verification video is ready</p>
                    <button
                      phx-click="rerecord_video"
                      class="text-sm text-gray-600 hover:text-gray-800 underline"
                    >
                      Re-record video
                    </button>
                  </div>
                <% else %>
                  <!-- Video Preview/Recording Area -->
                  <div class="relative bg-gray-900 aspect-video">
                    <!-- Live Preview -->
                    <video
                      id="video-preview"
                      autoplay
                      muted
                      playsinline
                      class="hidden w-full h-full object-cover"
                    ></video>

                    <!-- Playback -->
                    <video
                      id="video-playback"
                      controls
                      playsinline
                      class="hidden w-full h-full object-cover"
                    ></video>

                    <!-- Idle State -->
                    <div id="idle-state" class={[@video_state != :idle && "hidden", "absolute inset-0 flex flex-col items-center justify-center text-white p-4"]}>
                      <.icon name="hero-video-camera" class="w-12 h-12 mb-3 text-gray-400" />
                      <p class="text-sm text-gray-300 text-center mb-4">
                        Position yourself in frame and click to start
                      </p>
                      <button
                        id="start-recording-btn"
                        type="button"
                        class="bg-emerald-600 hover:bg-emerald-700 text-white px-6 py-2.5 rounded-lg font-medium flex items-center gap-2 transition"
                      >
                        <.icon name="hero-video-camera" class="w-5 h-5" />
                        Start Recording
                      </button>
                    </div>

                    <!-- Countdown Overlay -->
                    <div
                      id="countdown"
                      class="hidden absolute inset-0 flex items-center justify-center bg-black/50"
                    >
                      <span class="text-6xl font-bold text-white">3</span>
                    </div>

                    <!-- Recording Indicator -->
                    <div
                      id="recording-indicator"
                      class="hidden absolute top-4 left-4 flex items-center gap-2 bg-red-600 text-white px-3 py-1.5 rounded-full text-sm font-medium"
                    >
                      <span class="w-2 h-2 bg-white rounded-full animate-pulse"></span>
                      Recording <span id="recording-timer">0s</span>
                    </div>

                    <!-- Stop Button -->
                    <button
                      id="stop-recording-btn"
                      type="button"
                      class="hidden absolute bottom-4 left-1/2 -translate-x-1/2 bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg font-medium transition"
                    >
                      Stop Recording
                    </button>
                  </div>

                  <!-- Playback Controls -->
                  <div id="playback-controls" class="hidden p-4 bg-gray-50 border-t flex justify-center gap-3">
                    <button
                      id="retake-btn"
                      type="button"
                      class="hidden px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium hover:bg-gray-100 transition"
                    >
                      Retake
                    </button>
                    <button
                      id="confirm-btn"
                      type="button"
                      class="hidden px-4 py-2 bg-emerald-600 text-white rounded-lg text-sm font-medium hover:bg-emerald-700 transition"
                    >
                      Confirm & Use This Video
                    </button>
                  </div>
                <% end %>
              </div>

              <p class="text-xs text-gray-500 mt-2">
                This ensures everyone on the platform is a real human
              </p>
            </div>
          <% end %>

          <!-- Social Profile (optional) -->
          <%= if needs_video?(@user_type) do %>
            <div class="mb-6">
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Social Profile <span class="text-gray-400 font-normal">(optional)</span>
              </label>
              <input
                type="url"
                value={@form_data.social_link}
                phx-blur="update_form"
                phx-value-field="social_link"
                class="w-full border rounded-lg px-3 py-2.5 focus:border-emerald-500 focus:ring-emerald-500"
                placeholder="LinkedIn, Twitter/X, IMDb, Stage32..."
              />
              <p class="text-xs text-gray-500 mt-1">Adds credibility to your profile</p>
            </div>
          <% end %>

          <!-- Complete Button -->
          <.button
            phx-click="complete_verification"
            disabled={not can_complete?(assigns)}
            class="w-full"
            size="lg"
          >
            <%= if @user_type == "visitor", do: "Complete & Start Browsing", else: "Complete Verification" %>
          </.button>
        </div>

        <!-- Skip Link for Visitors -->
        <%= if @user_type == "visitor" do %>
          <p class="text-center mt-4 text-sm text-gray-500">
            <.link navigate={~p"/browse"} class="hover:underline">
              Skip for now and browse as guest →
            </.link>
          </p>
        <% end %>
      </div>
    </div>
    """
  end
end
