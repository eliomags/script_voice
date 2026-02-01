defmodule ScriptVoiceWeb.CommissionRequestLive do
  @moduledoc """
  LiveView for writers to create commission requests.
  Multi-step form: Select Performer -> Set Budget -> Confirm & Pay
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Accounts
  alias ScriptVoice.Commissions
  alias ScriptVoice.Commissions.PriceCalculator
  alias ScriptVoice.Notifications

  @impl true
  def mount(%{"screenplay_id" => screenplay_id}, session, socket) do
    current_user = get_current_user(session)

    case current_user do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Please sign in to request a commission")
         |> push_navigate(to: ~p"/verify?type=visitor")}

      user ->
        screenplay = Screenplays.get_screenplay(screenplay_id)

        cond do
          is_nil(screenplay) ->
            {:ok,
             socket
             |> put_flash(:error, "Screenplay not found")
             |> push_navigate(to: ~p"/browse")}

          screenplay.writer_id != user.id ->
            {:ok,
             socket
             |> put_flash(:error, "You can only commission performances for your own screenplays")
             |> push_navigate(to: ~p"/screenplay/#{screenplay_id}")}

          true ->
            performers = list_available_performers()

            {:ok,
             socket
             |> assign(:current_user, user)
             |> assign(:screenplay, screenplay)
             |> assign(:performers, performers)
             |> assign(:step, 1)
             |> assign(:selected_performer, nil)
             |> assign(:pricing, nil)
             |> assign(:price_breakdown, nil)
             |> assign(:offer_amount, nil)
             |> assign(:deadline, nil)
             |> assign(:message, "")
             |> assign(:search_query, "")
             |> assign(:page_title, "Request Performance")}
        end
    end
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> Accounts.get_user(user_id)
    end
  end

  defp list_available_performers do
    # Get all voice artists with pricing who are accepting commissions
    Accounts.list_users(user_type: "voice_artist")
    |> Enum.filter(fn user ->
      pricing = Commissions.get_performer_pricing(user.id)
      pricing && pricing.is_accepting_commissions
    end)
    |> Enum.map(fn user ->
      pricing = Commissions.get_performer_pricing(user.id)
      Map.put(user, :pricing, pricing)
    end)
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  @impl true
  def handle_event("select_performer", %{"id" => performer_id}, socket) do
    performer = Enum.find(socket.assigns.performers, &(&1.id == performer_id))

    if performer do
      pricing = performer.pricing

      # Calculate price for this screenplay
      price_result = PriceCalculator.calculate(socket.assigns.screenplay, pricing)

      offer_amount = if price_result.base_amount_cents do
        price_result.base_amount_cents
      else
        nil
      end

      {:noreply,
       socket
       |> assign(:selected_performer, performer)
       |> assign(:pricing, pricing)
       |> assign(:price_breakdown, price_result)
       |> assign(:offer_amount, offer_amount)
       |> assign(:step, 2)}
    else
      {:noreply, put_flash(socket, :error, "Performer not found")}
    end
  end

  @impl true
  def handle_event("back_to_step_1", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, 1)
     |> assign(:selected_performer, nil)
     |> assign(:pricing, nil)
     |> assign(:price_breakdown, nil)}
  end

  @impl true
  def handle_event("update_offer", %{"amount" => amount_str}, socket) do
    amount = case Float.parse(amount_str) do
      {float, _} -> round(float * 100)
      :error -> socket.assigns.offer_amount
    end
    {:noreply, assign(socket, :offer_amount, amount)}
  end

  @impl true
  def handle_event("update_deadline", %{"deadline" => deadline_str}, socket) do
    deadline = case Date.from_iso8601(deadline_str) do
      {:ok, date} -> date
      _ -> nil
    end
    {:noreply, assign(socket, :deadline, deadline)}
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :message, message)}
  end

  @impl true
  def handle_event("proceed_to_payment", _params, socket) do
    # Validate inputs
    cond do
      is_nil(socket.assigns.offer_amount) or socket.assigns.offer_amount <= 0 ->
        {:noreply, put_flash(socket, :error, "Please enter an offer amount")}

      String.trim(socket.assigns.message) == "" ->
        {:noreply, put_flash(socket, :error, "Please include a message to the performer")}

      true ->
        # Calculate full payment breakdown
        full_breakdown = PriceCalculator.calculate_full_breakdown(socket.assigns.offer_amount)
        {:noreply,
         socket
         |> assign(:full_breakdown, full_breakdown)
         |> assign(:step, 3)}
    end
  end

  @impl true
  def handle_event("back_to_step_2", _params, socket) do
    {:noreply, assign(socket, :step, 2)}
  end

  @impl true
  def handle_event("submit_request", _params, socket) do
    # Check if performer has Stripe account set up
    performer = socket.assigns.selected_performer
    has_stripe = Commissions.performer_ready_for_payments?(performer.id)

    # For now, we'll create the commission request without immediate payment
    # Payment will be collected when performer accepts

    attrs = %{
      screenplay_id: socket.assigns.screenplay.id,
      writer_id: socket.assigns.current_user.id,
      performer_id: performer.id,
      calculated_amount_cents: socket.assigns.price_breakdown.base_amount_cents,
      offered_amount_cents: socket.assigns.offer_amount,
      writer_message: socket.assigns.message,
      deadline: socket.assigns.deadline,
      is_rush: is_rush?(socket.assigns.deadline, socket.assigns.pricing),
      retakes_included: socket.assigns.pricing.included_retakes
    }

    case Commissions.create_commission_request(attrs) do
      {:ok, commission} ->
        # Notify performer
        Notifications.notify_commission_request_received(
          performer.id,
          socket.assigns.current_user.name,
          socket.assigns.screenplay.title,
          commission.id
        )

        {:noreply,
         socket
         |> put_flash(:info, "Commission request sent!")
         |> push_navigate(to: ~p"/commissions/#{commission.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create commission request")}
    end
  end

  defp is_rush?(nil, _pricing), do: false
  defp is_rush?(deadline, pricing) do
    days_until = Date.diff(deadline, Date.utc_today())
    days_until < pricing.rush_days_threshold
  end

  defp filtered_performers(performers, query) when query == "" or is_nil(query), do: performers
  defp filtered_performers(performers, query) do
    query = String.downcase(query)
    Enum.filter(performers, fn p ->
      String.contains?(String.downcase(p.name), query)
    end)
  end

  defp cents_to_dollars(nil), do: ""
  defp cents_to_dollars(cents), do: :erlang.float_to_binary(cents / 100, decimals: 2)

  defp format_amount(nil), do: "Quote Required"
  defp format_amount(cents), do: "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-2xl mx-auto">
        <!-- Header -->
        <div class="mb-6">
          <.link navigate={~p"/screenplay/#{@screenplay.id}"} class="text-sm text-emerald-600 hover:underline mb-2 inline-block">
            &larr; Back to Screenplay
          </.link>
          <h1 class="text-2xl font-bold">Request Performance</h1>
          <p class="text-gray-500 mt-1">"<%= @screenplay.title %>"</p>
        </div>

        <!-- Progress Steps -->
        <div class="flex items-center gap-2 mb-8">
          <%= for {label, step_num} <- [{"Select Performer", 1}, {"Set Budget", 2}, {"Confirm", 3}] do %>
            <div class="flex items-center gap-2">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium " <>
                cond do
                  @step > step_num -> "bg-emerald-600 text-white"
                  @step == step_num -> "bg-emerald-100 text-emerald-700 ring-2 ring-emerald-600"
                  true -> "bg-gray-100 text-gray-400"
                end}>
                <%= step_num %>
              </div>
              <span class={"text-sm hidden sm:inline " <> if @step >= step_num, do: "text-gray-900", else: "text-gray-400"}>
                <%= label %>
              </span>
            </div>
            <%= if step_num < 3 do %>
              <div class={"flex-1 h-0.5 " <> if @step > step_num, do: "bg-emerald-600", else: "bg-gray-200"}></div>
            <% end %>
          <% end %>
        </div>

        <!-- Step 1: Select Performer -->
        <%= if @step == 1 do %>
          <div class="space-y-4">
            <!-- Search -->
            <div class="relative">
              <.icon name="hero-magnifying-glass" class="w-5 h-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                phx-change="search"
                phx-debounce="300"
                name="query"
                value={@search_query}
                placeholder="Search voice artists..."
                class="w-full pl-10 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
            </div>

            <!-- Screenplay Info -->
            <div class="bg-gray-50 rounded-lg p-4 text-sm">
              <p><strong>Pages:</strong> <%= @screenplay.page_count || 1 %></p>
              <p><strong>Characters:</strong> <%= length(@screenplay.characters || []) %></p>
            </div>

            <!-- Performer List -->
            <%= if filtered_performers(@performers, @search_query) == [] do %>
              <div class="bg-white border rounded-xl p-8 text-center">
                <p class="text-gray-500">No voice artists available for commissions</p>
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for performer <- filtered_performers(@performers, @search_query) do %>
                  <button
                    phx-click="select_performer"
                    phx-value-id={performer.id}
                    class="w-full bg-white border rounded-xl p-4 hover:shadow-md hover:border-emerald-300 transition-all text-left"
                  >
                    <div class="flex items-start gap-4">
                      <!-- Avatar -->
                      <div class="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center flex-shrink-0">
                        <span class="text-lg font-bold text-purple-600">
                          <%= String.first(performer.name) %>
                        </span>
                      </div>

                      <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-2">
                          <h3 class="font-semibold"><%= performer.name %></h3>
                          <%= if performer.verification_status == "verified" do %>
                            <.icon name="hero-check-badge" class="w-4 h-4 text-emerald-600" />
                          <% end %>
                          <%= if performer.performer_type == "group" do %>
                            <span class="text-xs bg-purple-100 text-purple-700 px-2 py-0.5 rounded-full">Group</span>
                          <% end %>
                        </div>

                        <div class="text-sm text-gray-500 mt-1">
                          <%= pricing_summary(performer.pricing, @screenplay) %>
                        </div>

                        <div class="flex items-center gap-3 text-xs text-gray-400 mt-2">
                          <span><%= performer.pricing.included_retakes %> retakes included</span>
                          <span>~<%= performer.pricing.typical_turnaround_days %> day turnaround</span>
                        </div>
                      </div>

                      <div class="text-right">
                        <p class="font-semibold text-emerald-600">
                          <%= estimated_price(performer.pricing, @screenplay) %>
                        </p>
                      </div>
                    </div>
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Step 2: Set Budget -->
        <%= if @step == 2 do %>
          <div class="space-y-6">
            <!-- Selected Performer -->
            <div class="bg-white border rounded-xl p-4">
              <div class="flex items-center gap-4">
                <div class="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center">
                  <span class="text-lg font-bold text-purple-600">
                    <%= String.first(@selected_performer.name) %>
                  </span>
                </div>
                <div>
                  <h3 class="font-semibold"><%= @selected_performer.name %></h3>
                  <p class="text-sm text-gray-500"><%= pricing_summary(@pricing, @screenplay) %></p>
                </div>
              </div>
            </div>

            <!-- Price Calculation -->
            <div class="bg-emerald-50 border border-emerald-200 rounded-xl p-4">
              <h3 class="font-semibold mb-3">Price Calculation</h3>

              <%= if @price_breakdown.requires_quote do %>
                <p class="text-gray-600">This performer provides custom quotes. Enter your budget below.</p>
              <% else %>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span>Base Rate</span>
                    <span><%= format_amount(@price_breakdown.base_amount_cents) %></span>
                  </div>
                  <%= if @price_breakdown.minimum_applied do %>
                    <p class="text-xs text-gray-500">(Minimum rate applied)</p>
                  <% end %>
                  <div class="flex justify-between">
                    <span>Retakes Included</span>
                    <span><%= @pricing.included_retakes %></span>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Offer Amount -->
            <div class="bg-white border rounded-xl p-4">
              <label class="block font-semibold mb-2">Your Offer</label>
              <div class="relative">
                <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$</span>
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  phx-change="update_offer"
                  name="amount"
                  value={cents_to_dollars(@offer_amount)}
                  class="w-full pl-7 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                  placeholder="0.00"
                />
              </div>
              <%= if @price_breakdown.base_amount_cents && @offer_amount && @offer_amount < @price_breakdown.base_amount_cents do %>
                <p class="text-orange-600 text-sm mt-2">
                  This is below the calculated rate of <%= format_amount(@price_breakdown.base_amount_cents) %>
                </p>
              <% end %>
            </div>

            <!-- Deadline -->
            <div class="bg-white border rounded-xl p-4">
              <label class="block font-semibold mb-2">Deadline (optional)</label>
              <input
                type="date"
                phx-change="update_deadline"
                name="deadline"
                value={if @deadline, do: Date.to_iso8601(@deadline), else: ""}
                min={Date.to_iso8601(Date.add(Date.utc_today(), 1))}
                class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
              <%= if is_rush?(@deadline, @pricing) do %>
                <p class="text-orange-600 text-sm mt-2">
                  This is a rush job (&lt;<%= @pricing.rush_days_threshold %> days). Rush fee of <%= @pricing.rush_multiplier_percent %>% may apply.
                </p>
              <% end %>
            </div>

            <!-- Message -->
            <div class="bg-white border rounded-xl p-4">
              <label class="block font-semibold mb-2">Message to Performer</label>
              <textarea
                phx-change="update_message"
                name="message"
                rows="4"
                value={@message}
                class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                placeholder="Introduce yourself and explain what you're looking for..."
              ><%= @message %></textarea>
            </div>

            <!-- Navigation -->
            <div class="flex justify-between">
              <button
                phx-click="back_to_step_1"
                class="text-gray-600 px-4 py-2 hover:text-gray-900"
              >
                &larr; Back
              </button>
              <button
                phx-click="proceed_to_payment"
                class="bg-emerald-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-emerald-700"
              >
                Continue to Payment &rarr;
              </button>
            </div>
          </div>
        <% end %>

        <!-- Step 3: Confirm & Pay -->
        <%= if @step == 3 do %>
          <div class="space-y-6">
            <!-- Summary -->
            <div class="bg-white border rounded-xl p-4 sm:p-6">
              <h3 class="font-semibold mb-4">Commission Summary</h3>

              <div class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <span class="text-gray-600">Screenplay</span>
                  <span class="font-medium"><%= @screenplay.title %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">Performer</span>
                  <span class="font-medium"><%= @selected_performer.name %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">Retakes Included</span>
                  <span class="font-medium"><%= @pricing.included_retakes %></span>
                </div>
                <%= if @deadline do %>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Deadline</span>
                    <span class="font-medium"><%= Calendar.strftime(@deadline, "%B %d, %Y") %></span>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Payment Breakdown -->
            <div class="bg-white border rounded-xl p-4 sm:p-6">
              <h3 class="font-semibold mb-4">Payment Details</h3>

              <div class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <span class="text-gray-600">Commission Amount</span>
                  <span><%= format_amount(@full_breakdown.commission_amount_cents) %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">Processing Fee (2.9% + $0.30)</span>
                  <span><%= format_amount(@full_breakdown.processing_fee_cents) %></span>
                </div>
                <hr />
                <div class="flex justify-between font-semibold">
                  <span>Total</span>
                  <span class="text-emerald-600"><%= format_amount(@full_breakdown.total_cents) %></span>
                </div>
              </div>

              <p class="text-xs text-gray-500 mt-4">
                Payment will be held in escrow until the commission is completed.
                The performer will receive <%= format_amount(@full_breakdown.performer_payout_cents) %> (after 10% platform fee).
              </p>
            </div>

            <!-- Terms -->
            <div class="bg-gray-50 rounded-xl p-4 text-sm text-gray-600">
              <p class="font-medium text-gray-900 mb-2">By submitting this request, you agree to:</p>
              <ul class="list-disc list-inside space-y-1">
                <li>Our <.link href="#" class="text-emerald-600 hover:underline">Dispute Resolution Rules</.link></li>
                <li>Payment will be held until the commission is completed or disputed</li>
                <li>You cannot cancel after the performer accepts</li>
              </ul>
            </div>

            <!-- Navigation -->
            <div class="flex justify-between">
              <button
                phx-click="back_to_step_2"
                class="text-gray-600 px-4 py-2 hover:text-gray-900"
              >
                &larr; Back
              </button>
              <button
                phx-click="submit_request"
                class="bg-emerald-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-emerald-700"
              >
                Send Commission Request
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp pricing_summary(pricing, _screenplay) do
    case pricing.pricing_model do
      "per_page" -> "#{format_amount(pricing.per_page_rate_cents)}/page"
      "per_page_per_character" -> "#{format_amount(pricing.per_page_rate_cents)}/page + #{format_amount(pricing.per_character_rate_cents)}/character"
      "flat" -> "#{format_amount(pricing.flat_rate_cents)} flat rate"
      "quote" -> "Custom quotes"
    end
  end

  defp estimated_price(pricing, screenplay) do
    result = PriceCalculator.calculate(screenplay, pricing)
    format_amount(result.base_amount_cents)
  end
end
