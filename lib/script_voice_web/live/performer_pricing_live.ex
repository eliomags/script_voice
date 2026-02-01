defmodule ScriptVoiceWeb.PerformerPricingLive do
  @moduledoc """
  LiveView for performers to configure their commission pricing settings.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Commissions
  alias ScriptVoice.Commissions.PerformerPricing

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    case current_user do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Please sign in to access this page")
         |> push_navigate(to: ~p"/verify?type=visitor")}

      user when user.user_type != "voice_artist" ->
        {:ok,
         socket
         |> put_flash(:error, "Only voice artists can set pricing")
         |> push_navigate(to: ~p"/browse")}

      user ->
        pricing = Commissions.get_performer_pricing_or_default(user.id)
        changeset = PerformerPricing.changeset(pricing, %{})

        {:ok,
         socket
         |> assign(:current_user, user)
         |> assign(:pricing, pricing)
         |> assign(:form, to_form(changeset))
         |> assign(:page_title, "Pricing Settings")}
    end
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> ScriptVoice.Accounts.get_user(user_id)
    end
  end

  @impl true
  def handle_event("validate", %{"performer_pricing" => params}, socket) do
    params = convert_dollar_params(params)

    changeset =
      socket.assigns.pricing
      |> PerformerPricing.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"performer_pricing" => params}, socket) do
    params = convert_dollar_params(params)

    case Commissions.upsert_performer_pricing(socket.assigns.current_user.id, params) do
      {:ok, pricing} ->
        {:noreply,
         socket
         |> assign(:pricing, pricing)
         |> put_flash(:info, "Pricing settings saved successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Convert dollar inputs to cents
  defp convert_dollar_params(params) do
    dollar_fields = ~w(per_page_rate per_character_rate flat_rate minimum_rate retake_rate)

    Enum.reduce(dollar_fields, params, fn field, acc ->
      dollar_key = field <> "_dollars"
      cents_key = field <> "_cents"

      case Map.get(acc, dollar_key) do
        nil -> acc
        "" -> Map.put(acc, cents_key, nil)
        value ->
          cents = case Float.parse(value) do
            {float, _} -> round(float * 100)
            :error -> nil
          end
          Map.put(acc, cents_key, cents)
      end
    end)
  end

  # Convert cents to dollars for display
  defp cents_to_dollars(nil), do: ""
  defp cents_to_dollars(cents), do: :erlang.float_to_binary(cents / 100, decimals: 2)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-2xl mx-auto">
        <!-- Header -->
        <div class="mb-6">
          <.link navigate={~p"/profile/#{@current_user.id}"} class="text-sm text-emerald-600 hover:underline mb-2 inline-block">
            &larr; Back to Profile
          </.link>
          <h1 class="text-2xl font-bold">Pricing Settings</h1>
          <p class="text-gray-500 mt-1">Configure how you charge for commission work</p>
        </div>

        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
          <!-- Availability Toggle -->
          <div class="bg-white border rounded-xl p-4 sm:p-6">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="font-semibold">Accepting Commissions</h2>
                <p class="text-sm text-gray-500">Turn off to pause new requests</p>
              </div>
              <label class="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  name={@form[:is_accepting_commissions].name}
                  checked={@form[:is_accepting_commissions].value}
                  class="sr-only peer"
                />
                <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-emerald-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600"></div>
              </label>
            </div>
          </div>

          <!-- Pricing Model -->
          <div class="bg-white border rounded-xl p-4 sm:p-6">
            <h2 class="font-semibold mb-4">Pricing Model</h2>

            <div class="space-y-3">
              <label class="flex items-start gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50">
                <input
                  type="radio"
                  name={@form[:pricing_model].name}
                  value="per_page"
                  checked={@form[:pricing_model].value == "per_page"}
                  class="mt-1"
                />
                <div>
                  <div class="font-medium">Per Page</div>
                  <div class="text-sm text-gray-500">Charge a flat rate for each page of the screenplay</div>
                </div>
              </label>

              <label class="flex items-start gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50">
                <input
                  type="radio"
                  name={@form[:pricing_model].name}
                  value="per_page_per_character"
                  checked={@form[:pricing_model].value == "per_page_per_character"}
                  class="mt-1"
                />
                <div>
                  <div class="font-medium">Per Page + Per Character</div>
                  <div class="text-sm text-gray-500">Base rate per page, plus additional per character</div>
                </div>
              </label>

              <label class="flex items-start gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50">
                <input
                  type="radio"
                  name={@form[:pricing_model].name}
                  value="flat"
                  checked={@form[:pricing_model].value == "flat"}
                  class="mt-1"
                />
                <div>
                  <div class="font-medium">Flat Rate</div>
                  <div class="text-sm text-gray-500">Single price for any project</div>
                </div>
              </label>

              <label class="flex items-start gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50">
                <input
                  type="radio"
                  name={@form[:pricing_model].name}
                  value="quote"
                  checked={@form[:pricing_model].value == "quote"}
                  class="mt-1"
                />
                <div>
                  <div class="font-medium">Custom Quote</div>
                  <div class="text-sm text-gray-500">Provide individual quotes for each project</div>
                </div>
              </label>
            </div>
          </div>

          <!-- Rate Settings -->
          <div class="bg-white border rounded-xl p-4 sm:p-6">
            <h2 class="font-semibold mb-4">Rate Settings</h2>

            <div class="space-y-4">
              <%= if @form[:pricing_model].value in ["per_page", "per_page_per_character"] do %>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Per Page Rate
                  </label>
                  <div class="relative">
                    <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$</span>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      name="performer_pricing[per_page_rate_dollars]"
                      value={cents_to_dollars(@form[:per_page_rate_cents].value)}
                      class="w-full pl-7 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                      placeholder="0.00"
                    />
                  </div>
                </div>
              <% end %>

              <%= if @form[:pricing_model].value == "per_page_per_character" do %>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Additional Per Character (per page)
                  </label>
                  <div class="relative">
                    <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$</span>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      name="performer_pricing[per_character_rate_dollars]"
                      value={cents_to_dollars(@form[:per_character_rate_cents].value)}
                      class="w-full pl-7 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                      placeholder="0.00"
                    />
                  </div>
                  <p class="text-xs text-gray-500 mt-1">Added for each character × number of pages</p>
                </div>
              <% end %>

              <%= if @form[:pricing_model].value == "flat" do %>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Flat Rate
                  </label>
                  <div class="relative">
                    <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$</span>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      name="performer_pricing[flat_rate_dollars]"
                      value={cents_to_dollars(@form[:flat_rate_cents].value)}
                      class="w-full pl-7 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                      placeholder="0.00"
                    />
                  </div>
                </div>
              <% end %>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Minimum Project Rate (optional)
                </label>
                <div class="relative">
                  <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$</span>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    name="performer_pricing[minimum_rate_dollars]"
                    value={cents_to_dollars(@form[:minimum_rate_cents].value)}
                    class="w-full pl-7 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                    placeholder="0.00"
                  />
                </div>
                <p class="text-xs text-gray-500 mt-1">Projects below this amount will use this as the minimum</p>
              </div>
            </div>
          </div>

          <!-- Retake Policy -->
          <div class="bg-white border rounded-xl p-4 sm:p-6">
            <h2 class="font-semibold mb-4">Retake Policy</h2>

            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Included Retakes
                </label>
                <select
                  name={@form[:included_retakes].name}
                  class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                >
                  <%= for i <- 0..5 do %>
                    <option value={i} selected={@form[:included_retakes].value == i}>
                      <%= i %> <%= if i == 1, do: "retake", else: "retakes" %>
                    </option>
                  <% end %>
                </select>
                <p class="text-xs text-gray-500 mt-1">How many revision rounds are included in your base rate</p>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Additional Retake Rate
                </label>
                <div class="relative">
                  <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$</span>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    name="performer_pricing[retake_rate_dollars]"
                    value={cents_to_dollars(@form[:retake_rate_cents].value)}
                    class="w-full pl-7 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                    placeholder="0.00"
                  />
                </div>
                <p class="text-xs text-gray-500 mt-1">Cost per additional retake beyond included amount</p>
              </div>
            </div>
          </div>

          <!-- Turnaround & Capacity -->
          <div class="bg-white border rounded-xl p-4 sm:p-6">
            <h2 class="font-semibold mb-4">Turnaround & Capacity</h2>

            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Typical Turnaround (days)
                </label>
                <input
                  type="number"
                  min="1"
                  max="90"
                  name={@form[:typical_turnaround_days].name}
                  value={@form[:typical_turnaround_days].value}
                  class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Max Concurrent Projects
                </label>
                <input
                  type="number"
                  min="1"
                  max="50"
                  name={@form[:max_concurrent_projects].name}
                  value={@form[:max_concurrent_projects].value}
                  class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>
            </div>
          </div>

          <!-- Rush Jobs -->
          <div class="bg-white border rounded-xl p-4 sm:p-6">
            <h2 class="font-semibold mb-4">Rush Jobs</h2>

            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Rush Threshold (days)
                </label>
                <input
                  type="number"
                  min="1"
                  max="14"
                  name={@form[:rush_days_threshold].name}
                  value={@form[:rush_days_threshold].value}
                  class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
                <p class="text-xs text-gray-500 mt-1">Projects with deadlines shorter than this are rush jobs</p>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Rush Fee (% additional)
                </label>
                <div class="relative">
                  <input
                    type="number"
                    min="0"
                    max="200"
                    name={@form[:rush_multiplier_percent].name}
                    value={@form[:rush_multiplier_percent].value}
                    class="w-full pr-8 px-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                  />
                  <span class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500">%</span>
                </div>
                <p class="text-xs text-gray-500 mt-1">e.g., 50% means rush jobs cost 1.5x normal rate</p>
              </div>
            </div>
          </div>

          <!-- Notes -->
          <div class="bg-white border rounded-xl p-4 sm:p-6">
            <h2 class="font-semibold mb-4">Notes for Writers</h2>
            <textarea
              name={@form[:notes].name}
              rows="4"
              class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              placeholder="Any special terms, restrictions, or information for potential clients..."
            ><%= @form[:notes].value %></textarea>
          </div>

          <!-- Save Button -->
          <div class="flex justify-end">
            <button
              type="submit"
              class="bg-emerald-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-emerald-700 focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2"
            >
              Save Pricing Settings
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
