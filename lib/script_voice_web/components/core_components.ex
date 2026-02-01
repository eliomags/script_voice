defmodule ScriptVoiceWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for ScriptVoice.

  Mobile-first design with touch-friendly interactions.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  import ScriptVoiceWeb.Gettext

  # ============================================================================
  # FLASH MESSAGES
  # ============================================================================

  @doc """
  Renders flash notices.
  """
  attr :flash, :map, required: true
  attr :kind, :atom, values: [:info, :error], required: true

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={"flash-#{@kind}"}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("#flash-#{@kind}")}
      role="alert"
      class={[
        "fixed top-4 right-4 left-4 sm:left-auto sm:w-96 z-50 rounded-lg p-4 shadow-lg",
        "flex items-center gap-3 text-sm font-medium cursor-pointer",
        @kind == :info && "bg-emerald-50 text-emerald-800 border border-emerald-200",
        @kind == :error && "bg-red-50 text-red-800 border border-red-200"
      ]}
    >
      <.icon :if={@kind == :info} name="hero-check-circle" class="w-5 h-5 text-emerald-500" />
      <.icon :if={@kind == :error} name="hero-exclamation-circle" class="w-5 h-5 text-red-500" />
      <span class="flex-1"><%= msg %></span>
      <button type="button" class="p-1 hover:bg-black/5 rounded">
        <.icon name="hero-x-mark" class="w-4 h-4" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} flash={@flash} />
    <.flash kind={:error} flash={@flash} />
    """
  end

  # ============================================================================
  # BADGES
  # ============================================================================

  @doc """
  Renders a genre badge with color-coding.
  """
  attr :genre, :string, required: true

  def genre_badge(assigns) do
    colors = %{
      "Sci-Fi" => "bg-purple-100 text-purple-700",
      "Romance" => "bg-pink-100 text-pink-700",
      "Thriller" => "bg-red-100 text-red-700",
      "Drama" => "bg-blue-100 text-blue-700",
      "Comedy" => "bg-yellow-100 text-yellow-700",
      "Horror" => "bg-gray-800 text-gray-100",
      "Action" => "bg-orange-100 text-orange-700"
    }

    assigns = assign(assigns, :color_class, Map.get(colors, assigns.genre, "bg-gray-100 text-gray-700"))

    ~H"""
    <span class={"px-2 py-1 rounded-full text-xs font-medium #{@color_class}"}>
      <%= @genre %>
    </span>
    """
  end

  @doc """
  Renders a gender badge.
  """
  attr :gender, :string, required: true

  def gender_badge(assigns) do
    colors = %{
      "Female" => "bg-pink-100 text-pink-700",
      "Male" => "bg-blue-100 text-blue-700",
      "Any" => "bg-gray-100 text-gray-600",
      "Unknown" => "bg-purple-100 text-purple-700"
    }

    assigns = assign(assigns, :color_class, Map.get(colors, assigns.gender, "bg-gray-100 text-gray-700"))

    ~H"""
    <span class={"px-2 py-0.5 rounded text-xs font-medium #{@color_class}"}>
      <%= @gender %>
    </span>
    """
  end

  @doc """
  Renders the verified badge (green shield).
  """
  def verified_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-0.5 text-emerald-600" title="Verified human">
      <.icon name="hero-shield-check-solid" class="w-3.5 h-3.5" />
    </span>
    """
  end

  @doc """
  Renders the author's pick badge.
  """
  def author_pick_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
      <.icon name="hero-trophy" class="w-3 h-3" />
      Author's Pick
    </span>
    """
  end

  @doc """
  Renders a "needs audio" badge.
  """
  def needs_audio_badge(assigns) do
    ~H"""
    <span class="px-2 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
      Needs Audio
    </span>
    """
  end

  @doc """
  Renders a performer type badge (Solo/Duo/Group).
  """
  attr :type, :string, required: true

  def performer_type_badge(assigns) do
    label = case assigns.type do
      "solo" -> "Solo"
      "duo" -> "Duo"
      "group" -> "Group"
      _ -> assigns.type
    end

    assigns = assign(assigns, :label, label)

    ~H"""
    <span class="text-xs bg-purple-100 text-purple-700 px-2 py-0.5 rounded-full">
      <%= @label %>
    </span>
    """
  end

  # ============================================================================
  # BUTTONS
  # ============================================================================

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :variant, :string, default: "primary"
  attr :size, :string, default: "md"
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(form name value phx-click phx-disable-with)

  slot :inner_block, required: true

  def button(assigns) do
    variant_classes = %{
      "primary" => "bg-emerald-600 text-white hover:bg-emerald-700 active:bg-emerald-800 disabled:bg-gray-300",
      "secondary" => "bg-gray-100 text-gray-700 hover:bg-gray-200 active:bg-gray-300",
      "outline" => "border-2 border-emerald-600 text-emerald-600 hover:bg-emerald-50 active:bg-emerald-100",
      "ghost" => "text-gray-600 hover:bg-gray-100 active:bg-gray-200",
      "danger" => "bg-red-600 text-white hover:bg-red-700 active:bg-red-800"
    }

    size_classes = %{
      "sm" => "px-3 py-1.5 text-sm",
      "md" => "px-4 py-2 text-sm",
      "lg" => "px-6 py-3 text-base"
    }

    assigns = assign(assigns, %{
      variant_class: Map.get(variant_classes, assigns.variant, variant_classes["primary"]),
      size_class: Map.get(size_classes, assigns.size, size_classes["md"])
    })

    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class={[
        "rounded-lg font-medium transition-colors duration-150",
        "flex items-center justify-center gap-2",
        "touch-manipulation select-none",
        "disabled:cursor-not-allowed disabled:opacity-50",
        @variant_class,
        @size_class,
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a like button with heart icon.
  Stops event propagation to prevent parent click handlers from firing.
  """
  attr :liked, :boolean, default: false
  attr :count, :integer, required: true
  attr :rest, :global

  def like_button(assigns) do
    ~H"""
    <button
      class={[
        "flex items-center gap-1 font-medium transition-colors touch-manipulation",
        @liked && "text-red-500",
        !@liked && "text-gray-400 hover:text-red-500"
      ]}
      onclick="event.stopPropagation();"
      {@rest}
    >
      <.icon
        name={if @liked, do: "hero-heart-solid", else: "hero-heart"}
        class="w-5 h-5"
      />
      <span class="text-sm"><%= @count %></span>
    </button>
    """
  end

  @doc """
  Renders a play/pause button.
  """
  attr :playing, :boolean, default: false
  attr :size, :string, default: "md"
  attr :rest, :global

  def play_button(assigns) do
    size_classes = %{
      "sm" => "w-10 h-10",
      "md" => "w-12 h-12",
      "lg" => "w-14 h-14"
    }

    icon_sizes = %{
      "sm" => "w-4 h-4",
      "md" => "w-5 h-5",
      "lg" => "w-6 h-6"
    }

    assigns = assign(assigns, %{
      size_class: Map.get(size_classes, assigns.size, size_classes["md"]),
      icon_size: Map.get(icon_sizes, assigns.size, icon_sizes["md"])
    })

    ~H"""
    <button
      class={[
        "bg-emerald-600 rounded-full flex items-center justify-center",
        "text-white hover:bg-emerald-700 active:bg-emerald-800",
        "transition-colors touch-manipulation flex-shrink-0",
        @size_class
      ]}
      {@rest}
    >
      <.icon
        name={if @playing, do: "hero-pause-solid", else: "hero-play-solid"}
        class={[@icon_size, !@playing && "ml-0.5"]}
      />
    </button>
    """
  end

  @doc """
  Renders an author pick toggle button.
  """
  attr :picked, :boolean, default: false
  attr :rest, :global

  def pick_button(assigns) do
    ~H"""
    <button
      class={[
        "flex items-center gap-1 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors",
        "touch-manipulation",
        @picked && "bg-amber-100 text-amber-700",
        !@picked && "bg-gray-100 text-gray-600 hover:bg-amber-50 hover:text-amber-600"
      ]}
      {@rest}
    >
      <.icon name={if @picked, do: "hero-check", else: "hero-trophy"} class="w-4 h-4" />
      <%= if @picked, do: "Picked", else: "Pick" %>
    </button>
    """
  end

  # ============================================================================
  # MODALS
  # ============================================================================

  @doc """
  Renders a modal dialog.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-black/50 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4">
          <.focus_wrap
            id={"#{@id}-container"}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            class={[
              "bg-white w-full sm:max-w-lg sm:rounded-2xl",
              "rounded-t-2xl sm:rounded-2xl",
              "shadow-xl transition-all max-h-[90vh] overflow-y-auto",
              "safe-area-inset-bottom"
            ]}
          >
            <div class="p-4 sm:p-6">
              <%= render_slot(@inner_block) %>
            </div>
          </.focus_wrap>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a modal header with close button.
  """
  attr :id, :string, required: true
  slot :inner_block, required: true

  def modal_header(assigns) do
    ~H"""
    <div class="flex justify-between items-center mb-6">
      <h3 class="text-xl font-bold"><%= render_slot(@inner_block) %></h3>
      <button
        phx-click={hide_modal(@id)}
        type="button"
        class="p-2 -mr-2 hover:bg-gray-100 rounded-full touch-manipulation"
        aria-label="Close"
      >
        <.icon name="hero-x-mark" class="w-5 h-5" />
      </button>
    </div>
    """
  end

  # ============================================================================
  # CARDS
  # ============================================================================

  @doc """
  Renders a screenplay card for the browse/list view.
  """
  attr :screenplay, :map, required: true
  attr :liked, :boolean, default: false
  attr :rest, :global

  def screenplay_card(assigns) do
    ~H"""
    <div
      class="bg-white border rounded-xl p-4 sm:p-5 hover:shadow-md transition cursor-pointer active:bg-gray-50"
      {@rest}
    >
      <div class="flex justify-between items-start mb-3">
        <div class="flex-1 min-w-0">
          <div class="flex flex-wrap items-center gap-2 mb-1">
            <h3 class="font-semibold text-lg truncate"><%= @screenplay.title %></h3>
            <.genre_badge genre={@screenplay.genre} />
            <%= if @screenplay.audio_version_count == 0 do %>
              <.needs_audio_badge />
            <% end %>
          </div>
          <p class="text-sm text-gray-500 mb-2">
            by <.link navigate={"/profile/#{@screenplay.writer_id}"} class="text-emerald-600 hover:underline" onclick="event.stopPropagation();"><%= @screenplay.writer_name %></.link> · <%= @screenplay.page_count %> pages
          </p>
          <p class="text-gray-600 text-sm line-clamp-2"><%= @screenplay.logline %></p>
        </div>
        <div class="text-right ml-4 flex flex-col items-end gap-2 flex-shrink-0">
          <.like_button liked={@liked} count={@screenplay.likes} phx-click="toggle_screenplay_like" phx-value-id={@screenplay.id} />
          <div class="flex items-center gap-1 text-emerald-600">
            <.icon name="hero-headphones" class="w-3.5 h-3.5" />
            <span class="text-sm"><%= @screenplay.audio_version_count %></span>
          </div>
        </div>
      </div>

      <!-- Character preview -->
      <div class="flex flex-wrap gap-1 mt-3">
        <%= for char <- Enum.take(@screenplay.characters, 4) do %>
          <span class="inline-flex items-center gap-1 text-xs bg-gray-100 px-2 py-1 rounded">
            <%= char.name %>
            <.gender_badge gender={char.gender} />
          </span>
        <% end %>
        <%= if length(@screenplay.characters) > 4 do %>
          <span class="text-xs text-gray-500 px-2 py-1">
            +<%= length(@screenplay.characters) - 4 %> more
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders an audio version card.
  """
  attr :audio_version, :map, required: true
  attr :playing, :boolean, default: false
  attr :liked, :boolean, default: false
  attr :is_author, :boolean, default: false
  attr :screenplay_id, :string, default: nil
  attr :rest, :global

  def audio_version_card(assigns) do
    # Build profile URL with optional from parameter for back navigation
    profile_url = if assigns.screenplay_id do
      "/profile/#{assigns.audio_version.submitted_by_id}?from=screenplay:#{assigns.screenplay_id}"
    else
      "/profile/#{assigns.audio_version.submitted_by_id}"
    end
    assigns = assign(assigns, :profile_url, profile_url)

    ~H"""
    <div class={[
      "bg-white border rounded-xl p-4",
      @audio_version.author_pick && "border-amber-300 bg-amber-50/30"
    ]}>
      <div class="flex items-center justify-between gap-4">
        <div class="flex items-center gap-3 sm:gap-4 flex-1 min-w-0">
          <.play_button
            playing={@playing}
            phx-click="toggle_play"
            phx-value-id={@audio_version.id}
          />
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <.link navigate={@profile_url} class="font-medium truncate text-emerald-600 hover:underline">
                <%= get_performer_display(@audio_version) %>
              </.link>
              <%= if @audio_version.verified do %>
                <.verified_badge />
              <% end %>
              <%= if @audio_version.performer_type != "solo" do %>
                <.performer_type_badge type={@audio_version.performer_type} />
              <% end %>
              <%= if @audio_version.author_pick do %>
                <.author_pick_badge />
              <% end %>
            </div>
            <div class="flex items-center gap-3 text-sm text-gray-500 mt-1">
              <span class="flex items-center gap-1">
                <.icon name="hero-clock" class="w-3.5 h-3.5" />
                <%= @audio_version.duration %>
              </span>
              <span class="hidden sm:inline"><%= @audio_version.date %></span>
            </div>
          </div>
        </div>

        <div class="flex items-center gap-2 sm:gap-4 flex-shrink-0">
          <.like_button
            liked={@liked}
            count={@audio_version.likes}
            phx-click="toggle_audio_like"
            phx-value-id={@audio_version.id}
          />
          <%= if @is_author do %>
            <.pick_button
              picked={@audio_version.author_pick}
              phx-click="toggle_author_pick"
              phx-value-id={@audio_version.id}
            />
          <% end %>
        </div>
      </div>

      <!-- Cast breakdown if available -->
      <%= if map_size(@audio_version.casting || %{}) > 0 do %>
        <div class="mt-3 pt-3 border-t">
          <p class="text-xs text-gray-500 mb-2">Cast:</p>
          <div class="flex flex-wrap gap-2">
            <%= for {char, actor} <- @audio_version.casting do %>
              <span class="text-xs bg-gray-100 px-2 py-1 rounded">
                <span class="font-medium"><%= char %></span> → <%= actor %>
              </span>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Audio progress bar when playing -->
      <%= if @playing do %>
        <div class="mt-4 bg-gray-100 rounded-lg h-2">
          <div class="bg-emerald-600 h-2 rounded-lg w-1/3 animate-pulse"></div>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_performer_display(audio_version) do
    case audio_version.performer_type do
      "solo" -> audio_version.group_name || List.first(audio_version.performers) || "Unknown"
      "duo" -> Enum.join(audio_version.performers, " & ")
      _ -> audio_version.group_name || Enum.join(audio_version.performers, ", ")
    end
  end

  # ============================================================================
  # CHARACTER LIST
  # ============================================================================

  @doc """
  Renders a character list panel.
  """
  attr :characters, :list, required: true

  def character_list(assigns) do
    ~H"""
    <div class="bg-gray-50 rounded-lg p-4">
      <h4 class="font-medium text-sm text-gray-700 mb-3 flex items-center gap-2">
        <.icon name="hero-users" class="w-4 h-4" />
        Characters (<%= length(@characters) %>)
      </h4>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <%= for char <- @characters do %>
          <div class="bg-white rounded-lg p-2 sm:p-3 border">
            <div class="flex items-center justify-between">
              <span class="font-medium text-sm truncate"><%= char.name %></span>
              <.gender_badge gender={char.gender} />
            </div>
            <p class="text-xs text-gray-500 mt-1"><%= char.estimated_lines %> lines</p>
            <%= if char.description do %>
              <p class="text-xs text-gray-400 mt-1 truncate"><%= char.description %></p>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # FORMS
  # ============================================================================

  @doc """
  Renders an input with label and error messages.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :checked, :boolean
  attr :prompt, :string, default: nil
  attr :options, :list
  attr :multiple, :boolean, default: false
  attr :rest, :global, include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                                   multiple pattern placeholder readonly required rows size step)
  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns = assign_new(assigns, :checked, fn ->
      Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
    end)

    ~H"""
    <div>
      <label class="flex items-center gap-3 text-sm cursor-pointer">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="w-5 h-5 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500"
          {@rest}
        />
        <%= @label %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class={[
          "block w-full rounded-lg border-gray-300 shadow-sm",
          "focus:border-emerald-500 focus:ring-emerald-500",
          "text-base py-2.5 px-3",
          @errors != [] && "border-red-300"
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "block w-full rounded-lg border-gray-300 shadow-sm min-h-[100px]",
          "focus:border-emerald-500 focus:ring-emerald-500",
          "text-base py-2.5 px-3 resize-y",
          @errors != [] && "border-red-300"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "block w-full rounded-lg border-gray-300 shadow-sm",
          "focus:border-emerald-500 focus:ring-emerald-500",
          "text-base py-2.5 px-3",
          @errors != [] && "border-red-300"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-medium text-gray-700 mb-1">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-1 text-sm text-red-600 flex items-center gap-1">
      <.icon name="hero-exclamation-circle-mini" class="w-4 h-4" />
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  # ============================================================================
  # FILE UPLOAD
  # ============================================================================

  @doc """
  Renders a file upload drop zone.
  """
  attr :accept, :string, default: "*/*"
  attr :icon, :string, default: "hero-document"
  attr :label, :string, default: "Drop file here or click to upload"
  attr :rest, :global

  def file_drop_zone(assigns) do
    ~H"""
    <div
      class="border-2 border-dashed rounded-lg p-6 sm:p-8 text-center hover:border-gray-400 transition cursor-pointer"
      {@rest}
    >
      <.icon name={@icon} class="mx-auto mb-2 text-gray-400 w-8 h-8" />
      <p class="text-sm text-gray-500"><%= @label %></p>
    </div>
    """
  end

  # ============================================================================
  # ICONS (using Heroicons)
  # ============================================================================

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="w-3 h-3 animate-spin ml-1" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: nil

  # Heart icons for likes
  def icon(%{name: "hero-heart-solid"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class={@class}>
      <path d="M11.645 20.91l-.007-.003-.022-.012a15.247 15.247 0 01-.383-.218 25.18 25.18 0 01-4.244-3.17C4.688 15.36 2.25 12.174 2.25 8.25 2.25 5.322 4.714 3 7.688 3A5.5 5.5 0 0112 5.052 5.5 5.5 0 0116.313 3c2.973 0 5.437 2.322 5.437 5.25 0 3.925-2.438 7.111-4.739 9.256a25.175 25.175 0 01-4.244 3.17 15.247 15.247 0 01-.383.219l-.022.012-.007.004-.003.001a.752.752 0 01-.704 0l-.003-.001z" />
    </svg>
    """
  end

  def icon(%{name: "hero-heart"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
    </svg>
    """
  end

  # Common icons
  def icon(%{name: "hero-headphones"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M19.114 5.636a9 9 0 010 12.728M16.463 8.288a5.25 5.25 0 010 7.424M6.75 8.25l4.72-4.72a.75.75 0 011.28.53v15.88a.75.75 0 01-1.28.53l-4.72-4.72H4.51c-.88 0-1.704-.507-1.938-1.354A9.01 9.01 0 012.25 12c0-.83.112-1.633.322-2.396C2.806 8.756 3.63 8.25 4.51 8.25H6.75z" />
    </svg>
    """
  end

  def icon(%{name: "hero-play-solid"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class={@class}>
      <path fill-rule="evenodd" d="M4.5 5.653c0-1.426 1.529-2.33 2.779-1.643l11.54 6.348c1.295.712 1.295 2.573 0 3.285L7.28 19.991c-1.25.687-2.779-.217-2.779-1.643V5.653z" clip-rule="evenodd" />
    </svg>
    """
  end

  def icon(%{name: "hero-pause-solid"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class={@class}>
      <path fill-rule="evenodd" d="M6.75 5.25a.75.75 0 01.75-.75H9a.75.75 0 01.75.75v13.5a.75.75 0 01-.75.75H7.5a.75.75 0 01-.75-.75V5.25zm7.5 0A.75.75 0 0115 4.5h1.5a.75.75 0 01.75.75v13.5a.75.75 0 01-.75.75H15a.75.75 0 01-.75-.75V5.25z" clip-rule="evenodd" />
    </svg>
    """
  end

  def icon(%{name: "hero-check-circle"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  def icon(%{name: "hero-exclamation-circle"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
    </svg>
    """
  end

  def icon(%{name: "hero-user-circle"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
    """
  end

  def icon(%{name: "hero-eye"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
    """
  end

  def icon(%{name: "hero-document-text"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
    </svg>
    """
  end

  def icon(%{name: "hero-microphone"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z" />
    </svg>
    """
  end

  def icon(%{name: "hero-video-camera"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" d="M15.75 10.5l4.72-4.72a.75.75 0 011.28.53v11.38a.75.75 0 01-1.28.53l-4.72-4.72M4.5 18.75h9a2.25 2.25 0 002.25-2.25v-9a2.25 2.25 0 00-2.25-2.25h-9A2.25 2.25 0 002.25 7.5v9a2.25 2.25 0 002.25 2.25z" />
    </svg>
    """
  end

  def icon(%{name: "hero-check-badge"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class={@class}>
      <path fill-rule="evenodd" d="M8.603 3.799A4.49 4.49 0 0112 2.25c1.357 0 2.573.6 3.397 1.549a4.49 4.49 0 013.498 1.307 4.491 4.491 0 011.307 3.497A4.49 4.49 0 0121.75 12a4.49 4.49 0 01-1.549 3.397 4.491 4.491 0 01-1.307 3.497 4.491 4.491 0 01-3.497 1.307A4.49 4.49 0 0112 21.75a4.49 4.49 0 01-3.397-1.549 4.49 4.49 0 01-3.498-1.306 4.491 4.491 0 01-1.307-3.498A4.49 4.49 0 012.25 12c0-1.357.6-2.573 1.549-3.397a4.49 4.49 0 011.307-3.497 4.49 4.49 0 013.497-1.307zm7.007 6.387a.75.75 0 10-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 00-1.06 1.06l2.25 2.25a.75.75 0 001.14-.094l3.75-5.25z" clip-rule="evenodd" />
    </svg>
    """
  end

  def icon(%{name: "hero-star-solid"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class={@class}>
      <path fill-rule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z" clip-rule="evenodd" />
    </svg>
    """
  end

  def icon(%{name: "hero-users"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" />
    </svg>
    """
  end

  def icon(%{name: "hero-user"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
    </svg>
    """
  end

  def icon(%{name: "hero-chevron-down"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
    </svg>
    """
  end

  def icon(%{name: "hero-arrow-right-on-rectangle"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15M12 9l-3 3m0 0l3 3m-3-3h12.75" />
    </svg>
    """
  end

  def icon(%{name: "hero-magnifying-glass"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
    </svg>
    """
  end

  def icon(%{name: "hero-arrow-left"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
    </svg>
    """
  end

  def icon(%{name: "hero-book-open"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25" />
    </svg>
    """
  end

  def icon(%{name: "hero-clock"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  # Fallback for any other icon - render as empty span (won't be visible but won't break)
  def icon(assigns) do
    ~H"""
    <span class={@class}></span>
    """
  end

  # ============================================================================
  # UTILITY COMPONENTS
  # ============================================================================

  @doc """
  Renders a simple form.
  """
  attr :for, :any, required: true
  attr :as, :any, default: nil
  attr :rest, :global, include: ~w(autocomplete name rel action enctype method novalidate target multipart)

  slot :inner_block, required: true

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="space-y-4">
        <%= render_slot(@inner_block, f) %>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={@actions != [] && "flex items-center justify-between gap-6"}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-zinc-800">
          <%= render_slot(@inner_block) %>
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-zinc-600">
          <%= render_slot(@subtitle) %>
        </p>
      </div>
      <div class="flex-none"><%= render_slot(@actions) %></div>
    </header>
    """
  end

  @doc """
  Renders a back navigation link.
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="text-gray-500 hover:text-gray-700 flex items-center gap-1 text-sm font-medium"
    >
      <.icon name="hero-arrow-left" class="w-4 h-4" />
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  @doc """
  Renders a loading spinner.
  """
  attr :class, :string, default: "w-5 h-5"

  def spinner(assigns) do
    ~H"""
    <svg class={["animate-spin", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    """
  end

  # ============================================================================
  # JS HELPERS
  # ============================================================================

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-container")
  end

  def hide_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      time: 200,
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(ScriptVoiceWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(ScriptVoiceWeb.Gettext, "errors", msg, opts)
    end
  end
end
