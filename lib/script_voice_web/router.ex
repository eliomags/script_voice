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

  scope "/", ScriptVoiceWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    live "/browse", BrowseLive, :index
    live "/screenplay/:id", ScreenplayLive, :show
    live "/profile/:id", ProfileLive, :show

    # Auth routes
    live "/verify", VerifyLive, :index
    get "/session/login/:user_id", SessionController, :create
    post "/session", SessionController, :create
    delete "/session", SessionController, :delete
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
