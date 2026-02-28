defmodule HoldcoWeb.InvestorPortalLive.Hooks do
  import Phoenix.LiveView
  import Phoenix.Component

  alias Holdco.Governance

  def on_mount(:ensure_investor, _params, _session, socket) do
    user = socket.assigns[:current_scope] && socket.assigns.current_scope.user

    if user do
      accesses = Governance.list_investor_accesses_for_user(user.id)

      if accesses != [] do
        {:cont,
         socket
         |> assign(:investor_accesses, accesses)
         |> assign(:investor_companies, Enum.map(accesses, & &1.company))
         |> assign(:can_write, false)
         |> assign(:can_admin, false)}
      else
        {:halt, redirect(socket, to: "/")}
      end
    else
      {:halt, redirect(socket, to: "/users/log-in")}
    end
  end
end
