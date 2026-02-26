defmodule HoldcoWeb.Live.Hooks do
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:current_path, _params, _session, socket) do
    {:cont,
     socket
     |> attach_hook(:current_path, :handle_params, fn _params, uri, socket ->
       path = URI.parse(uri).path
       {:cont, assign(socket, :current_path, path)}
     end)}
  end
end
