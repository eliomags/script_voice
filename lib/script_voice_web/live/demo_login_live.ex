defmodule ScriptVoiceWeb.DemoLoginLive do
  @moduledoc """
  Demo login page for testing purposes.
  Allows quick login to demo accounts without verification.
  Only available in dev/test environments.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Accounts

  @demo_accounts [
    # Writers
    %{email: "sarah@example.com", type: "writer", description: "Sci-fi and family drama writer"},
    %{email: "marcus@example.com", type: "writer", description: "Romance and drama writer"},
    %{email: "aisha@example.com", type: "writer", description: "Thriller writer"},
    # Solo Voice Artists
    %{email: "jake@example.com", type: "voice_artist", description: "Per page: $5/page, min $25"},
    %{email: "emma@example.com", type: "voice_artist", description: "Per page: $8/page, min $50"},
    %{email: "michael@example.com", type: "voice_artist", description: "Quote-based (flexible)"},
    # Group Voice Artists
    %{email: "lighthouse@example.com", type: "voice_artist", description: "The Lighthouse Collective - Flat rate: $150"},
    %{email: "kimtorres@example.com", type: "voice_artist", description: "David Kim & Rachel Torres - Per page + per character"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    # Load demo accounts with user data
    demo_accounts =
      @demo_accounts
      |> Enum.map(fn account ->
        user = Accounts.get_user_by_email(account.email)
        Map.put(account, :user, user)
      end)
      |> Enum.filter(fn account -> account.user != nil end)

    {:ok,
     socket
     |> assign(:demo_accounts, demo_accounts)
     |> assign(:page_title, "Demo Login")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8 px-4">
      <div class="max-w-2xl mx-auto">
        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold text-gray-900 mb-2">Demo Login</h1>
          <p class="text-gray-600">
            Click any account below to log in instantly for testing.
          </p>
          <div class="mt-2 inline-flex items-center gap-2 text-amber-600 bg-amber-50 px-3 py-1 rounded-full text-sm">
            <.icon name="hero-beaker" class="w-4 h-4" />
            Development Mode Only
          </div>
        </div>

        <%= if Enum.empty?(@demo_accounts) do %>
          <div class="bg-white rounded-xl border p-8 text-center">
            <.icon name="hero-exclamation-triangle" class="w-12 h-12 text-amber-500 mx-auto mb-4" />
            <h3 class="font-semibold text-lg mb-2">No demo accounts found</h3>
            <p class="text-gray-600 mb-4">
              Run <code class="bg-gray-100 px-2 py-1 rounded">mix ecto.reset</code> to seed demo data.
            </p>
          </div>
        <% else %>
          <!-- Writers Section -->
          <div class="mb-8">
            <h2 class="text-lg font-semibold text-gray-900 mb-3 flex items-center gap-2">
              <.icon name="hero-document-text" class="w-5 h-5 text-purple-600" />
              Writers
            </h2>
            <div class="space-y-3">
              <%= for account <- Enum.filter(@demo_accounts, & &1.type == "writer") do %>
                <.demo_account_card account={account} />
              <% end %>
            </div>
          </div>

          <!-- Voice Artists Section -->
          <div class="mb-8">
            <h2 class="text-lg font-semibold text-gray-900 mb-3 flex items-center gap-2">
              <.icon name="hero-microphone" class="w-5 h-5 text-pink-600" />
              Voice Artists
            </h2>
            <div class="space-y-3">
              <%= for account <- Enum.filter(@demo_accounts, & &1.type == "voice_artist") do %>
                <.demo_account_card account={account} />
              <% end %>
            </div>
          </div>
        <% end %>

        <div class="text-center mt-8">
          <.link navigate={~p"/"} class="text-emerald-600 font-medium hover:underline">
            ← Back to Home
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp demo_account_card(assigns) do
    ~H"""
    <.link
      href={~p"/session/login/#{@account.user.id}"}
      class="block bg-white border rounded-xl p-4 hover:border-emerald-500 hover:shadow-md transition group"
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class={[
            "w-10 h-10 rounded-full flex items-center justify-center text-white font-semibold",
            @account.type == "writer" && "bg-purple-500",
            @account.type == "voice_artist" && "bg-pink-500"
          ]}>
            <%= String.first(@account.user.name) %>
          </div>
          <div>
            <div class="font-semibold text-gray-900"><%= @account.user.name %></div>
            <div class="text-sm text-gray-500"><%= @account.email %></div>
            <div class="text-xs text-gray-400 mt-0.5"><%= @account.description %></div>
          </div>
        </div>
        <div class="text-emerald-600 opacity-0 group-hover:opacity-100 transition">
          <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" />
        </div>
      </div>
    </.link>
    """
  end
end
