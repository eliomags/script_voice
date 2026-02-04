defmodule ScriptVoiceWeb.LoginLive do
  @moduledoc """
  Login LiveView - Handles login for registered users via phone or email verification.

  Unlike the verification/signup flow, this only asks for contact info
  and verifies the user exists before sending a code.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Accounts

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    # Redirect if already logged in
    if current_user do
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Log In")
       |> assign(:step, :contact_info)
       |> assign(:verify_method, nil)
       |> assign(:code_sent, false)
       |> assign(:contact_value, "")
       |> assign(:submitted_code, "")
       |> assign(:found_user, nil)
       |> assign(:error, nil)}
    end
  end

  @impl true
  def handle_event("update_contact", %{"value" => value}, socket) do
    # Auto-detect if it's email or phone based on content
    method = detect_method(value)
    {:noreply,
     socket
     |> assign(:contact_value, value)
     |> assign(:verify_method, method)}
  end

  @impl true
  def handle_event("send_code", _, socket) do
    contact = String.trim(socket.assigns.contact_value)
    method = socket.assigns.verify_method

    if contact == "" do
      {:noreply, assign(socket, :error, "Please enter your email or phone number")}
    else
      # Look up user first
      user = lookup_user(contact, method)

      if user do
        # User exists - send verification code
        Accounts.create_verification_code(user.id, method, contact)
        {:noreply,
         socket
         |> assign(:code_sent, true)
         |> assign(:found_user, user)
         |> assign(:error, nil)}
      else
        # User not found
        {:noreply,
         socket
         |> assign(:error, "No account found with this #{if method == "phone", do: "phone number", else: "email"}. Please sign up first.")}
      end
    end
  end

  @impl true
  def handle_event("verify_code", %{"code" => code}, socket) do
    method = socket.assigns.verify_method
    contact = socket.assigns.contact_value

    case Accounts.verify_code(contact, method, code) do
      {:ok, _} ->
        # Code verified - log the user in
        user = socket.assigns.found_user
        {:noreply,
         socket
         |> redirect(to: ~p"/session/login/#{user.id}")}

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

  defp detect_method(value) do
    cond do
      String.contains?(value, "@") -> "email"
      String.match?(value, ~r/^[\+\d\s\-\(\)]+$/) and String.length(value) >= 6 -> "phone"
      true -> nil
    end
  end

  defp lookup_user(contact, "email"), do: Accounts.get_user_by_email(contact)
  defp lookup_user(contact, "phone"), do: Accounts.get_user_by_phone(contact)
  defp lookup_user(_, _), do: nil

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> Accounts.get_user(user_id)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8 px-4 sm:px-6">
      <div class="max-w-md mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <div class="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <.icon name="hero-arrow-right-on-rectangle" class="w-8 h-8 text-emerald-600" />
          </div>
          <h1 class="text-2xl font-bold">Welcome Back</h1>
          <p class="text-gray-600 mt-2">
            Log in with your email or phone number
          </p>
        </div>

        <!-- Login Card -->
        <div class="bg-white rounded-2xl shadow-sm border p-6">
          <!-- Error Display -->
          <%= if @error do %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
              <.icon name="hero-exclamation-circle" class="w-5 h-5 flex-shrink-0" />
              <span><%= @error %></span>
            </div>
          <% end %>

          <%= if !@code_sent do %>
            <!-- Contact Input -->
            <div class="mb-6">
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Email or Phone Number
              </label>
              <input
                type="text"
                value={@contact_value}
                phx-keyup="update_contact"
                phx-key="*"
                class={[
                  "w-full border rounded-lg px-4 py-3 focus:border-emerald-500 focus:ring-emerald-500",
                  @verify_method && "border-emerald-500 ring-1 ring-emerald-500"
                ]}
                placeholder="your@email.com or +1 555 000 0000"
                autofocus
              />
              <%= if @verify_method do %>
                <p class="text-xs text-emerald-600 mt-1 flex items-center gap-1">
                  <.icon name="hero-check-circle" class="w-3 h-3" />
                  Detected as <%= if @verify_method == "phone", do: "phone number", else: "email" %>
                </p>
              <% end %>
            </div>

            <!-- Send Code Button -->
            <.button
              phx-click="send_code"
              disabled={@verify_method == nil}
              class="w-full"
              size="lg"
            >
              Send Verification Code
            </.button>
          <% else %>
            <!-- Code Entry -->
            <div class="mb-4">
              <div class="bg-emerald-50 rounded-lg p-3 mb-4 flex items-start gap-2">
                <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-600 flex-shrink-0 mt-0.5" />
                <div>
                  <p class="text-sm text-emerald-800">
                    Code sent to <span class="font-medium"><%= @contact_value %></span>
                  </p>
                  <p class="text-xs text-emerald-600 mt-1">
                    Welcome back, <%= @found_user.name %>!
                  </p>
                </div>
              </div>

              <label class="block text-sm font-medium text-gray-700 mb-2">
                Enter 6-digit code
              </label>
              <div class="flex gap-2">
                <input
                  type="text"
                  maxlength="6"
                  value={@submitted_code}
                  phx-keyup="update_code"
                  phx-key="*"
                  class="flex-1 border rounded-lg px-4 py-3 text-center tracking-widest font-mono text-lg focus:border-emerald-500 focus:ring-emerald-500"
                  placeholder="000000"
                  autofocus
                />
              </div>
            </div>

            <!-- Verify Button -->
            <.button
              phx-click="verify_code"
              phx-value-code={@submitted_code}
              disabled={String.length(@submitted_code) < 6}
              class="w-full mb-4"
              size="lg"
            >
              Log In
            </.button>

            <!-- Resend Link -->
            <button
              phx-click="resend_code"
              class="w-full text-center text-sm text-gray-500 hover:text-gray-700"
            >
              Didn't receive the code? <span class="underline">Try again</span>
            </button>
          <% end %>
        </div>

        <!-- Sign Up Link -->
        <p class="text-center mt-6 text-sm text-gray-600">
          Don't have an account?
          <.link navigate={~p"/verify"} class="text-emerald-600 font-medium hover:underline">
            Sign up
          </.link>
        </p>

        <!-- Demo Login Link (for development) -->
        <p class="text-center mt-2 text-sm text-gray-400">
          <.link navigate={~p"/demo-login"} class="hover:underline">
            Use demo account
          </.link>
        </p>
      </div>
    </div>
    """
  end
end
