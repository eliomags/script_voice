defmodule ScriptVoiceWeb.Router do
  use ScriptVoiceWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ScriptVoiceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Pipeline for Stripe webhooks - no CSRF protection, raw body preserved
  pipeline :stripe_webhook do
    plug :accepts, ["json"]
    plug ScriptVoiceWeb.Plugs.RawBodyReader
  end

  scope "/", ScriptVoiceWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    live "/dashboard", DashboardLive, :index
    live "/browse", BrowseLive, :index
    live "/screenplay/:id", ScreenplayLive, :show
    live "/screenplay/:id/edit", ScreenplayEditLive, :edit
    live "/screenplay/:id/read", ScriptReaderLive, :show
    live "/profile/:id", ProfileLive, :show

    # Auth routes
    live "/verify", VerifyLive, :index
    live "/demo-login", DemoLoginLive, :index
    get "/session/login/:user_id", SessionController, :create
    post "/session", SessionController, :create
    delete "/session", SessionController, :delete

    # Commission routes
    # Redirect /commissions to dashboard with commissions tab
    get "/commissions", SessionController, :redirect_to_commissions
    live "/commissions/payment/success", PaymentSuccessLive, :success
    live "/commissions/:id", CommissionDetailLive, :show
    live "/commissions/request/:screenplay_id", CommissionRequestLive, :new

    # Performer pricing settings
    live "/settings/pricing", PerformerPricingLive, :edit

    # Stripe Connect onboarding
    live "/settings/payments", StripeConnectLive, :index

    # Collective routes
    live "/collectives", CollectivesBrowseLive, :index
    live "/collective/:slug", CollectiveLive, :show
    live "/collective/:slug/settings", CollectiveSettingsLive, :edit

    # Project routes (series/anthology management)
    live "/project/:id", ProjectLive, :show
    live "/project/:id/episode/new", ProjectLive, :new_episode
    live "/project/:id/season/:season_id", ProjectLive, :show_season
    live "/project/:id/bible", ProjectLive, :bible

    # API-style routes (still in browser pipeline for session access)
    get "/api/bible-template/:project_id", BibleTemplateController, :show
  end

  # Stripe webhook endpoint
  scope "/webhooks", ScriptVoiceWeb do
    pipe_through :stripe_webhook

    post "/stripe", StripeWebhookController, :handle
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:script_voice, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ScriptVoiceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Plug to fetch current user from session
  defp fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && ScriptVoice.Accounts.get_user(user_id)
    assign(conn, :current_user, user)
  end
end
