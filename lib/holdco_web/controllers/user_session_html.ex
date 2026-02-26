defmodule HoldcoWeb.UserSessionHTML do
  use HoldcoWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:holdco, Holdco.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
