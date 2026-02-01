defmodule ScriptVoice.Commissions.PriceCalculator do
  @moduledoc """
  Calculates commission prices based on performer pricing and screenplay details.
  """

  alias ScriptVoice.Commissions.PerformerPricing

  @platform_fee_percent 10
  @stripe_fee_percent Decimal.new("2.9")
  @stripe_fee_fixed_cents 30

  @doc """
  Calculates the commission price based on screenplay and performer pricing.
  Returns a breakdown map with all costs.
  """
  def calculate(screenplay, %PerformerPricing{} = pricing) do
    base_amount = calculate_base_amount(screenplay, pricing)

    case base_amount do
      nil ->
        %{
          base_amount_cents: nil,
          pricing_model: pricing.pricing_model,
          requires_quote: true,
          breakdown: build_breakdown(screenplay, pricing),
          included_retakes: pricing.included_retakes,
          retake_rate_cents: pricing.retake_rate_cents
        }

      amount ->
        # Apply minimum rate
        final_base = if pricing.minimum_rate_cents do
          max(amount, pricing.minimum_rate_cents)
        else
          amount
        end

        %{
          base_amount_cents: final_base,
          pricing_model: pricing.pricing_model,
          requires_quote: false,
          breakdown: build_breakdown(screenplay, pricing),
          included_retakes: pricing.included_retakes,
          retake_rate_cents: pricing.retake_rate_cents,
          minimum_applied: final_base != amount
        }
    end
  end

  @doc """
  Calculates rush fee if applicable.
  """
  def calculate_rush_fee(base_amount_cents, %PerformerPricing{} = pricing, deadline) do
    if rush_order?(deadline, pricing.rush_days_threshold) do
      rush_amount = div(base_amount_cents * pricing.rush_multiplier_percent, 100)
      %{is_rush: true, rush_fee_cents: rush_amount}
    else
      %{is_rush: false, rush_fee_cents: 0}
    end
  end

  @doc """
  Calculates the full payment breakdown including all fees.
  """
  def calculate_full_breakdown(commission_amount_cents) do
    # Stripe fee: 2.9% + $0.30
    stripe_percentage_fee = Decimal.mult(commission_amount_cents, @stripe_fee_percent)
      |> Decimal.div(100)
      |> Decimal.round(0, :up)
      |> Decimal.to_integer()

    processing_fee_cents = stripe_percentage_fee + @stripe_fee_fixed_cents

    # Platform fee: 10%
    platform_fee_cents = div(commission_amount_cents * @platform_fee_percent, 100)

    # Total writer pays
    total_cents = commission_amount_cents + processing_fee_cents

    # Performer receives (commission minus platform fee)
    performer_payout_cents = commission_amount_cents - platform_fee_cents

    %{
      commission_amount_cents: commission_amount_cents,
      processing_fee_cents: processing_fee_cents,
      platform_fee_cents: platform_fee_cents,
      total_cents: total_cents,
      performer_payout_cents: performer_payout_cents,
      fee_breakdown: %{
        stripe_percent: Decimal.to_string(@stripe_fee_percent),
        stripe_fixed: @stripe_fee_fixed_cents,
        platform_percent: @platform_fee_percent
      }
    }
  end

  @doc """
  Formats cents to human readable dollar amount.
  """
  def format_cents(cents) when is_integer(cents) do
    dollars = cents / 100
    "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
  end
  def format_cents(_), do: nil

  # Private functions

  defp calculate_base_amount(screenplay, %PerformerPricing{pricing_model: "per_page"} = pricing) do
    page_count = screenplay.page_count || 1
    page_count * pricing.per_page_rate_cents
  end

  defp calculate_base_amount(screenplay, %PerformerPricing{pricing_model: "per_page_per_character"} = pricing) do
    page_count = screenplay.page_count || 1
    char_count = length(screenplay.characters || [])

    page_amount = page_count * pricing.per_page_rate_cents
    char_amount = page_count * char_count * (pricing.per_character_rate_cents || 0)

    page_amount + char_amount
  end

  defp calculate_base_amount(_screenplay, %PerformerPricing{pricing_model: "flat"} = pricing) do
    pricing.flat_rate_cents
  end

  defp calculate_base_amount(_screenplay, %PerformerPricing{pricing_model: "quote"}) do
    nil
  end

  defp calculate_base_amount(_screenplay, _pricing), do: nil

  defp build_breakdown(screenplay, pricing) do
    %{
      pages: screenplay.page_count,
      characters: length(screenplay.characters || []),
      per_page_rate: pricing.per_page_rate_cents,
      per_character_rate: pricing.per_character_rate_cents,
      flat_rate: pricing.flat_rate_cents,
      minimum_rate: pricing.minimum_rate_cents
    }
  end

  defp rush_order?(nil, _threshold), do: false
  defp rush_order?(deadline, threshold) do
    days_until = Date.diff(deadline, Date.utc_today())
    days_until < threshold
  end
end
