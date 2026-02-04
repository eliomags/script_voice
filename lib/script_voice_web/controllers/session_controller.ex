defmodule ScriptVoiceWeb.SessionController do
  use ScriptVoiceWeb, :controller

  alias ScriptVoice.Accounts

  def create(conn, params) do
    user_id = params["user_id"]

    case Accounts.get_user(user_id) do
      nil ->
        conn
        |> put_flash(:error, "User not found")
        |> redirect(to: ~p"/verify")

      _user ->
        conn
        |> put_session(:user_id, user_id)
        |> put_flash(:info, "Welcome to ScriptVivo!")
        |> redirect(to: ~p"/dashboard")
    end
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: ~p"/")
  end

  def redirect_to_commissions(conn, _params) do
    redirect(conn, to: ~p"/dashboard?tab=commissions")
  end
end
