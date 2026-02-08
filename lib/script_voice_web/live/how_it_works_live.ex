defmodule ScriptVoiceWeb.HowItWorksLive do
  @moduledoc """
  How It Works page - comprehensive guide with three tabs:
  Writers, Voice Artists (Narrators), and Audience.
  Each tab explains the full workflow with embedded links to verify all routes work.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.Screenplay

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    # Load a few sample stories for the embedded links
    sample_stories = Screenplays.list_screenplays(sort: :popular, limit: 3)

    # Get a sample story with blocks for reader demo
    sample_with_blocks =
      sample_stories
      |> Enum.find(fn sp -> Screenplay.has_blocks?(sp) end)

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:active_tab, "writers")
     |> assign(:sample_stories, sample_stories)
     |> assign(:sample_with_blocks, sample_with_blocks)
     |> assign(:page_title, "How It Works")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = Map.get(params, "tab", "writers")
    tab = if tab in ["writers", "narrators", "audience"], do: tab, else: "writers"
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/htw?tab=#{tab}")}
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> ScriptVoice.Accounts.get_user(user_id)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-8 px-4 sm:px-6">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-3xl sm:text-4xl font-bold text-gray-900 mb-3">How ScriptVivo Works</h1>
          <p class="text-lg text-gray-600 max-w-2xl mx-auto">
            A platform where writers publish stories and voice artists bring them to life.
            Every link below is live &mdash; test each flow end-to-end.
          </p>
        </div>

        <!-- Tab Switcher -->
        <div class="flex justify-center mb-8">
          <div class="inline-flex rounded-xl bg-gray-100 p-1">
            <button
              phx-click="switch_tab"
              phx-value-tab="writers"
              class={"px-5 py-2.5 rounded-lg text-sm font-medium transition #{if @active_tab == "writers", do: "bg-emerald-600 text-white shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            >
              <.icon name="hero-pencil-square" class="w-4 h-4 inline mr-1" />
              Writers
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="narrators"
              class={"px-5 py-2.5 rounded-lg text-sm font-medium transition #{if @active_tab == "narrators", do: "bg-pink-600 text-white shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            >
              <.icon name="hero-microphone" class="w-4 h-4 inline mr-1" />
              Voice Artists
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="audience"
              class={"px-5 py-2.5 rounded-lg text-sm font-medium transition #{if @active_tab == "audience", do: "bg-blue-600 text-white shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            >
              <.icon name="hero-eye" class="w-4 h-4 inline mr-1" />
              Audience
            </button>
          </div>
        </div>

        <!-- Tab Content -->
        <%= case @active_tab do %>
          <% "writers" -> %>
            <.writers_tab
              current_user={@current_user}
              sample_stories={@sample_stories}
              sample_with_blocks={@sample_with_blocks}
            />
          <% "narrators" -> %>
            <.narrators_tab
              current_user={@current_user}
              sample_stories={@sample_stories}
              sample_with_blocks={@sample_with_blocks}
            />
          <% "audience" -> %>
            <.audience_tab
              current_user={@current_user}
              sample_stories={@sample_stories}
              sample_with_blocks={@sample_with_blocks}
            />
        <% end %>

        <!-- Quick Navigation -->
        <div class="mt-12 bg-gray-50 rounded-xl p-6">
          <h3 class="font-semibold text-gray-900 mb-4">Quick Links (All Routes)</h3>
          <div class="grid sm:grid-cols-3 gap-4 text-sm">
            <div>
              <h4 class="font-medium text-gray-700 mb-2">Main Pages</h4>
              <ul class="space-y-1.5">
                <li><.link navigate={~p"/"} class="text-emerald-600 hover:underline">Home</.link></li>
                <li><.link navigate={~p"/browse"} class="text-emerald-600 hover:underline">Browse Stories</.link></li>
                <li><.link navigate={~p"/collectives"} class="text-emerald-600 hover:underline">Browse Collectives</.link></li>
                <li><.link navigate={~p"/htw"} class="text-emerald-600 hover:underline">How It Works (this page)</.link></li>
              </ul>
            </div>
            <div>
              <h4 class="font-medium text-gray-700 mb-2">Auth & Account</h4>
              <ul class="space-y-1.5">
                <li><.link navigate={~p"/verify?type=writer"} class="text-emerald-600 hover:underline">Sign Up as Writer</.link></li>
                <li><.link navigate={~p"/verify?type=voice_artist"} class="text-emerald-600 hover:underline">Sign Up as Voice Artist</.link></li>
                <li><.link navigate={~p"/login"} class="text-emerald-600 hover:underline">Log In</.link></li>
                <li><.link navigate={~p"/demo-login"} class="text-emerald-600 hover:underline">Demo Login</.link></li>
                <%= if @current_user do %>
                  <li><.link navigate={~p"/dashboard"} class="text-emerald-600 hover:underline">Dashboard</.link></li>
                  <li><.link navigate={~p"/profile/#{@current_user.id}"} class="text-emerald-600 hover:underline">My Profile</.link></li>
                <% end %>
              </ul>
            </div>
            <div>
              <h4 class="font-medium text-gray-700 mb-2">Sample Stories</h4>
              <ul class="space-y-1.5">
                <%= for sp <- @sample_stories do %>
                  <li>
                    <.link navigate={~p"/screenplay/#{sp.id}"} class="text-emerald-600 hover:underline">
                      <%= sp.title %>
                    </.link>
                    <span class="text-gray-400 text-xs ml-1">
                      (<.link navigate={~p"/screenplay/#{sp.id}/read"} class="text-blue-500 hover:underline">read</.link>
                      · <.link navigate={~p"/screenplay/#{sp.id}/edit"} class="text-blue-500 hover:underline">edit</.link>)
                    </span>
                  </li>
                <% end %>
                <%= if @current_user && @current_user.user_type == "writer" do %>
                  <li class="pt-1">
                    <.link navigate={~p"/dashboard?tab=screenplays"} class="text-emerald-600 hover:underline font-medium">My Stories (Dashboard)</.link>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Writers Tab ───────────────────────────────────────────────────────────

  attr :current_user, :map, default: nil
  attr :sample_stories, :list, default: []
  attr :sample_with_blocks, :map, default: nil

  defp writers_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Step 1: Get Verified -->
      <.step_card
        number={1}
        title="Get Verified"
        icon="hero-shield-check"
        color="emerald"
      >
        <p class="text-gray-600 mb-3">
          Create your account and verify your identity. This keeps the platform authentic
          and builds trust with voice artists who will perform your work.
        </p>
        <div class="flex flex-wrap gap-2">
          <.link navigate={~p"/verify?type=writer"} class="text-sm bg-emerald-50 text-emerald-700 px-3 py-1.5 rounded-lg hover:bg-emerald-100 font-medium">
            Sign up as Writer &rarr;
          </.link>
          <.link navigate={~p"/demo-login"} class="text-sm bg-gray-100 text-gray-600 px-3 py-1.5 rounded-lg hover:bg-gray-200 font-medium">
            Try Demo Login
          </.link>
        </div>
      </.step_card>

      <!-- Step 2: Create a Story -->
      <.step_card
        number={2}
        title="Create a Story"
        icon="hero-document-plus"
        color="purple"
      >
        <p class="text-gray-600 mb-3">
          Start by creating a new story with a title, genre, and logline. You can create
          standalone stories or organize them into projects (series, anthologies, etc).
        </p>
        <div class="bg-gray-50 rounded-lg p-4 mb-3">
          <p class="text-sm font-medium text-gray-700 mb-2">Two places to create stories:</p>
          <ul class="text-sm text-gray-600 space-y-1">
            <li class="flex items-center gap-2">
              <.icon name="hero-check" class="w-4 h-4 text-emerald-500" />
              <.link navigate={~p"/browse"} class="text-emerald-600 hover:underline">Browse page</.link> &mdash; "Create Story" button (top-right, writers only)
            </li>
            <li class="flex items-center gap-2">
              <.icon name="hero-check" class="w-4 h-4 text-emerald-500" />
              <.link navigate={~p"/dashboard?tab=screenplays"} class="text-emerald-600 hover:underline">Dashboard &gt; My Stories</.link> &mdash; "New Story" button
            </li>
          </ul>
        </div>
        <p class="text-sm text-gray-500">
          After creating, you're redirected to the <strong>Story Editor</strong> automatically.
        </p>
      </.step_card>

      <!-- Step 3: Story Editor -->
      <.step_card
        number={3}
        title="Write in the Story Editor"
        icon="hero-pencil-square"
        color="blue"
      >
        <p class="text-gray-600 mb-3">
          The unified Story Editor is your creative workspace. Three ways to add content:
        </p>
        <div class="grid sm:grid-cols-3 gap-3 mb-3">
          <div class="bg-blue-50 rounded-lg p-3">
            <h4 class="font-medium text-blue-800 text-sm mb-1">Build Blocks</h4>
            <p class="text-xs text-blue-600">Add narration, dialogue, SFX, music, scene breaks, chapters, and pauses one at a time.</p>
          </div>
          <div class="bg-blue-50 rounded-lg p-3">
            <h4 class="font-medium text-blue-800 text-sm mb-1">Paste Text</h4>
            <p class="text-xs text-blue-600">Open the Import panel, paste text, click "Load into Editor" &mdash; splits into paragraph blocks.</p>
          </div>
          <div class="bg-blue-50 rounded-lg p-3">
            <h4 class="font-medium text-blue-800 text-sm mb-1">Upload File</h4>
            <p class="text-xs text-blue-600">Drop a .txt or .pdf file in the Import panel. Text is extracted and loaded as blocks.</p>
          </div>
        </div>
        <div class="bg-gray-50 rounded-lg p-4 mb-3">
          <p class="text-sm font-medium text-gray-700 mb-2">Block types available:</p>
          <div class="flex flex-wrap gap-2">
            <span class="text-xs bg-white border px-2 py-1 rounded">Chapter</span>
            <span class="text-xs bg-white border px-2 py-1 rounded">Scene Break</span>
            <span class="text-xs bg-white border px-2 py-1 rounded">Narration</span>
            <span class="text-xs bg-white border px-2 py-1 rounded">Dialogue</span>
            <span class="text-xs bg-white border px-2 py-1 rounded">SFX</span>
            <span class="text-xs bg-white border px-2 py-1 rounded">Music</span>
            <span class="text-xs bg-white border px-2 py-1 rounded">Pause</span>
          </div>
        </div>
        <%= if @sample_with_blocks do %>
          <div class="flex flex-wrap gap-2">
            <.link navigate={~p"/screenplay/#{@sample_with_blocks.id}/edit"} class="text-sm bg-blue-50 text-blue-700 px-3 py-1.5 rounded-lg hover:bg-blue-100 font-medium">
              Try editing "<%= @sample_with_blocks.title %>" &rarr;
            </.link>
            <.link navigate={~p"/screenplay/#{@sample_with_blocks.id}/read"} class="text-sm bg-gray-100 text-gray-600 px-3 py-1.5 rounded-lg hover:bg-gray-200 font-medium">
              Read it &rarr;
            </.link>
          </div>
        <% end %>
      </.step_card>

      <!-- Step 4: Projects -->
      <.step_card
        number={4}
        title="Organize into Projects"
        icon="hero-folder"
        color="violet"
      >
        <p class="text-gray-600 mb-3">
          Group related stories into projects like TV series, anthologies, podcast dramas,
          or film collections. Each project has seasons, episodes, a series bible, and
          shared characters.
        </p>
        <div class="flex flex-wrap gap-2">
          <.link navigate={~p"/browse"} class="text-sm bg-violet-50 text-violet-700 px-3 py-1.5 rounded-lg hover:bg-violet-100 font-medium">
            Browse Projects &rarr;
          </.link>
          <.link navigate={~p"/dashboard?tab=screenplays"} class="text-sm bg-gray-100 text-gray-600 px-3 py-1.5 rounded-lg hover:bg-gray-200 font-medium">
            Create Project (Dashboard)
          </.link>
        </div>
      </.step_card>

      <!-- Step 5: Get Performed -->
      <.step_card
        number={5}
        title="Get Your Story Performed"
        icon="hero-speaker-wave"
        color="amber"
      >
        <p class="text-gray-600 mb-3">
          Once published, voice artists can discover your story on the Browse page and submit
          audio performances. You can also directly commission voice artists.
        </p>
        <div class="bg-gray-50 rounded-lg p-4">
          <p class="text-sm font-medium text-gray-700 mb-2">Ways to get audio:</p>
          <ul class="text-sm text-gray-600 space-y-1">
            <li class="flex items-center gap-2">
              <.icon name="hero-check" class="w-4 h-4 text-amber-500" />
              Voice artists browse and submit voluntarily
            </li>
            <li class="flex items-center gap-2">
              <.icon name="hero-check" class="w-4 h-4 text-amber-500" />
              Commission a specific voice artist or collective
            </li>
            <li class="flex items-center gap-2">
              <.icon name="hero-check" class="w-4 h-4 text-amber-500" />
              Mark your favorite recordings as "Author's Pick"
            </li>
          </ul>
        </div>
      </.step_card>
    </div>
    """
  end

  # ── Narrators Tab ─────────────────────────────────────────────────────────

  attr :current_user, :map, default: nil
  attr :sample_stories, :list, default: []
  attr :sample_with_blocks, :map, default: nil

  defp narrators_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Step 1: Get Verified -->
      <.step_card
        number={1}
        title="Get Verified"
        icon="hero-shield-check"
        color="pink"
      >
        <p class="text-gray-600 mb-3">
          Sign up as a voice artist and verify your identity with a short video.
          This builds trust with writers and shows you're a real performer.
        </p>
        <div class="flex flex-wrap gap-2">
          <.link navigate={~p"/verify?type=voice_artist"} class="text-sm bg-pink-50 text-pink-700 px-3 py-1.5 rounded-lg hover:bg-pink-100 font-medium">
            Sign up as Voice Artist &rarr;
          </.link>
          <.link navigate={~p"/demo-login"} class="text-sm bg-gray-100 text-gray-600 px-3 py-1.5 rounded-lg hover:bg-gray-200 font-medium">
            Try Demo Login
          </.link>
        </div>
      </.step_card>

      <!-- Step 2: Browse Stories -->
      <.step_card
        number={2}
        title="Discover Stories"
        icon="hero-book-open"
        color="emerald"
      >
        <p class="text-gray-600 mb-3">
          Browse published stories filtered by genre. Each story card shows duration,
          word count, and whether it needs audio. Click to read the full story.
        </p>
        <div class="bg-gray-50 rounded-lg p-4 mb-3">
          <p class="text-sm font-medium text-gray-700 mb-2">Story cards show:</p>
          <div class="flex flex-wrap gap-2 text-xs">
            <span class="bg-white border px-2 py-1 rounded">~X min estimated duration</span>
            <span class="bg-white border px-2 py-1 rounded">Y words</span>
            <span class="bg-white border px-2 py-1 rounded">Genre badge</span>
            <span class="bg-white border px-2 py-1 rounded text-amber-600 bg-amber-50 border-amber-200">Needs Audio</span>
            <span class="bg-white border px-2 py-1 rounded">Character list</span>
          </div>
        </div>
        <div class="flex flex-wrap gap-2">
          <.link navigate={~p"/browse"} class="text-sm bg-emerald-50 text-emerald-700 px-3 py-1.5 rounded-lg hover:bg-emerald-100 font-medium">
            Browse Stories &rarr;
          </.link>
          <%= if @sample_with_blocks do %>
            <.link navigate={~p"/screenplay/#{@sample_with_blocks.id}"} class="text-sm bg-gray-100 text-gray-600 px-3 py-1.5 rounded-lg hover:bg-gray-200 font-medium">
              View "<%= @sample_with_blocks.title %>"
            </.link>
          <% end %>
        </div>
      </.step_card>

      <!-- Step 3: Read in Script View -->
      <.step_card
        number={3}
        title="Read in Script View"
        icon="hero-document-text"
        color="blue"
      >
        <p class="text-gray-600 mb-3">
          The Story Reader has two modes. As a voice artist, you'll default to
          <strong>Script View</strong> which shows formatted script with character cues,
          SFX markers, and estimated timestamps.
        </p>
        <div class="grid sm:grid-cols-2 gap-3 mb-3">
          <div class="bg-blue-50 rounded-lg p-3">
            <h4 class="font-medium text-blue-800 text-sm mb-1">Reader View</h4>
            <p class="text-xs text-blue-600">Clean prose for reading enjoyment. Great for understanding the story first.</p>
          </div>
          <div class="bg-pink-50 rounded-lg p-3">
            <h4 class="font-medium text-pink-800 text-sm mb-1">Script View</h4>
            <p class="text-xs text-pink-600">Formatted for recording. Shows character names, parentheticals, SFX cues, timestamps.</p>
          </div>
        </div>
        <%= if @sample_with_blocks do %>
          <.link navigate={~p"/screenplay/#{@sample_with_blocks.id}/read"} class="text-sm bg-blue-50 text-blue-700 px-3 py-1.5 rounded-lg hover:bg-blue-100 font-medium">
            Read "<%= @sample_with_blocks.title %>" &rarr;
          </.link>
        <% end %>
      </.step_card>

      <!-- Step 4: Submit Audio -->
      <.step_card
        number={4}
        title="Record & Submit"
        icon="hero-microphone"
        color="rose"
      >
        <p class="text-gray-600 mb-3">
          On any story page, click "Submit Version" to upload your audio recording.
          You can submit as a solo performer or as part of a collective (ensemble group).
        </p>
        <div class="bg-gray-50 rounded-lg p-4">
          <p class="text-sm font-medium text-gray-700 mb-2">Submission options:</p>
          <ul class="text-sm text-gray-600 space-y-1">
            <li class="flex items-center gap-2">
              <.icon name="hero-user" class="w-4 h-4 text-rose-500" />
              Solo &mdash; individual performance
            </li>
            <li class="flex items-center gap-2">
              <.icon name="hero-user-group" class="w-4 h-4 text-purple-500" />
              Collective &mdash; submit on behalf of your ensemble
            </li>
          </ul>
        </div>
      </.step_card>

      <!-- Step 5: Collectives -->
      <.step_card
        number={5}
        title="Join or Create Collectives"
        icon="hero-user-group"
        color="purple"
      >
        <p class="text-gray-600 mb-3">
          Collectives are groups of voice artists who perform together. Create your own
          ensemble or join existing ones. Collectives can submit audio and take commissions
          as a group.
        </p>
        <div class="flex flex-wrap gap-2">
          <.link navigate={~p"/collectives"} class="text-sm bg-purple-50 text-purple-700 px-3 py-1.5 rounded-lg hover:bg-purple-100 font-medium">
            Browse Collectives &rarr;
          </.link>
          <.link navigate={~p"/dashboard?tab=collectives"} class="text-sm bg-gray-100 text-gray-600 px-3 py-1.5 rounded-lg hover:bg-gray-200 font-medium">
            My Collectives (Dashboard)
          </.link>
        </div>
      </.step_card>

      <!-- Step 6: Commissions & Pricing -->
      <.step_card
        number={6}
        title="Earn via Commissions"
        icon="hero-currency-dollar"
        color="amber"
      >
        <p class="text-gray-600 mb-3">
          Set your pricing and writers can commission you directly. Payments are processed
          through Stripe Connect. Set up your rates and payment account from the dashboard.
        </p>
        <div class="flex flex-wrap gap-2">
          <.link navigate={~p"/settings/pricing"} class="text-sm bg-amber-50 text-amber-700 px-3 py-1.5 rounded-lg hover:bg-amber-100 font-medium">
            Set Pricing &rarr;
          </.link>
          <.link navigate={~p"/settings/payments"} class="text-sm bg-gray-100 text-gray-600 px-3 py-1.5 rounded-lg hover:bg-gray-200 font-medium">
            Payment Settings
          </.link>
          <.link navigate={~p"/dashboard?tab=commissions"} class="text-sm bg-gray-100 text-gray-600 px-3 py-1.5 rounded-lg hover:bg-gray-200 font-medium">
            My Commissions
          </.link>
        </div>
      </.step_card>
    </div>
    """
  end

  # ── Audience Tab ──────────────────────────────────────────────────────────

  attr :current_user, :map, default: nil
  attr :sample_stories, :list, default: []
  attr :sample_with_blocks, :map, default: nil

  defp audience_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- No Signup Required -->
      <.step_card
        number={1}
        title="Browse Without Signing Up"
        icon="hero-eye"
        color="blue"
      >
        <p class="text-gray-600 mb-3">
          You don't need an account to browse stories, read them, or listen to audio recordings.
          ScriptVivo is open for discovery.
        </p>
        <div class="flex flex-wrap gap-2">
          <.link navigate={~p"/browse"} class="text-sm bg-blue-50 text-blue-700 px-3 py-1.5 rounded-lg hover:bg-blue-100 font-medium">
            Browse Stories &rarr;
          </.link>
          <.link navigate={~p"/collectives"} class="text-sm bg-purple-50 text-purple-700 px-3 py-1.5 rounded-lg hover:bg-purple-100 font-medium">
            Browse Collectives &rarr;
          </.link>
        </div>
      </.step_card>

      <!-- Read Stories -->
      <.step_card
        number={2}
        title="Read Stories"
        icon="hero-book-open"
        color="emerald"
      >
        <p class="text-gray-600 mb-3">
          Click any story to see its details, then "Read Story" to open the reader.
          Stories with block-based content show a clean Reader View. Legacy stories
          display raw text or PDFs.
        </p>
        <div class="bg-gray-50 rounded-lg p-4 mb-3">
          <p class="text-sm font-medium text-gray-700 mb-2">Story detail page shows:</p>
          <ul class="text-sm text-gray-600 space-y-1">
            <li class="flex items-center gap-2">
              <.icon name="hero-check" class="w-4 h-4 text-emerald-500" />
              Title, genre, logline, writer profile link
            </li>
            <li class="flex items-center gap-2">
              <.icon name="hero-check" class="w-4 h-4 text-emerald-500" />
              Duration estimate, word count, scene count, character list
            </li>
            <li class="flex items-center gap-2">
              <.icon name="hero-check" class="w-4 h-4 text-emerald-500" />
              All audio versions with play buttons
            </li>
            <li class="flex items-center gap-2">
              <.icon name="hero-check" class="w-4 h-4 text-emerald-500" />
              Like button, version history
            </li>
          </ul>
        </div>
        <%= for sp <- Enum.take(@sample_stories, 2) do %>
          <div class="flex flex-wrap gap-2 mb-2">
            <.link navigate={~p"/screenplay/#{sp.id}"} class="text-sm bg-emerald-50 text-emerald-700 px-3 py-1.5 rounded-lg hover:bg-emerald-100 font-medium">
              "<%= sp.title %>" detail &rarr;
            </.link>
            <.link navigate={~p"/screenplay/#{sp.id}/read"} class="text-sm bg-gray-100 text-gray-600 px-3 py-1.5 rounded-lg hover:bg-gray-200 font-medium">
              Read it
            </.link>
          </div>
        <% end %>
      </.step_card>

      <!-- Listen to Audio -->
      <.step_card
        number={3}
        title="Listen to Performances"
        icon="hero-speaker-wave"
        color="pink"
      >
        <p class="text-gray-600 mb-3">
          Each story can have multiple audio versions by different voice artists.
          Listen directly from the story page. Solo and collective performances
          are labeled differently.
        </p>
        <p class="text-sm text-gray-500">
          Audio players are on each story's detail page. Writers can mark their
          favorite recordings as "Author's Pick" (shown with a gold badge).
        </p>
      </.step_card>

      <!-- Like & Engage -->
      <.step_card
        number={4}
        title="Like & Engage"
        icon="hero-heart"
        color="red"
      >
        <p class="text-gray-600 mb-3">
          Like your favorite stories and audio recordings. To like, you'll need a free
          account (any type). Likes help surface the best content.
        </p>
        <p class="text-sm text-gray-500">
          Not signed up yet? You'll be prompted to
          <.link navigate={~p"/verify?type=visitor"} class="text-emerald-600 hover:underline">create a free account</.link>
          when you try to like something.
        </p>
      </.step_card>

      <!-- Explore Profiles -->
      <.step_card
        number={5}
        title="Explore Profiles"
        icon="hero-user"
        color="violet"
      >
        <p class="text-gray-600 mb-3">
          Every writer and voice artist has a public profile page showing their work,
          verification video, bio, and social links. Click any name to visit their profile.
        </p>
        <div class="bg-gray-50 rounded-lg p-4">
          <p class="text-sm font-medium text-gray-700 mb-2">Writer profiles show:</p>
          <ul class="text-sm text-gray-600 space-y-1">
            <li>&bull; All published stories with like counts</li>
            <li>&bull; Bio, social links, verification badge</li>
          </ul>
          <p class="text-sm font-medium text-gray-700 mt-3 mb-2">Voice artist profiles show:</p>
          <ul class="text-sm text-gray-600 space-y-1">
            <li>&bull; All audio recordings</li>
            <li>&bull; Collective memberships</li>
            <li>&bull; Intro video, bio, verification badge</li>
          </ul>
        </div>
      </.step_card>
    </div>
    """
  end

  # ── Shared Components ─────────────────────────────────────────────────────

  attr :number, :integer, required: true
  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true
  slot :inner_block, required: true

  defp step_card(assigns) do
    bg_class = case assigns.color do
      "emerald" -> "bg-emerald-100 text-emerald-700"
      "purple" -> "bg-purple-100 text-purple-700"
      "blue" -> "bg-blue-100 text-blue-700"
      "pink" -> "bg-pink-100 text-pink-700"
      "amber" -> "bg-amber-100 text-amber-700"
      "rose" -> "bg-rose-100 text-rose-700"
      "violet" -> "bg-violet-100 text-violet-700"
      "red" -> "bg-red-100 text-red-700"
      _ -> "bg-gray-100 text-gray-700"
    end

    assigns = assign(assigns, :bg_class, bg_class)

    ~H"""
    <div class="bg-white border rounded-xl p-5 sm:p-6">
      <div class="flex items-start gap-4">
        <div class={"w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 #{@bg_class}"}>
          <span class="text-sm font-bold"><%= @number %></span>
        </div>
        <div class="flex-1 min-w-0">
          <h3 class="text-lg font-semibold text-gray-900 mb-2 flex items-center gap-2">
            <.icon name={@icon} class="w-5 h-5" />
            <%= @title %>
          </h3>
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end
end
