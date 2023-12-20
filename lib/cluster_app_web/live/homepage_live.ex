defmodule ClusterAppWeb.HomePageLive do
  use ClusterAppWeb, :live_view

  alias ClusterApp.AnonymousUser
  alias ClusterAppWeb.Presence


  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      if connected?(socket) do
        user = create_anonymous_user()
        ClusterAppWeb.Endpoint.subscribe("lv:homepage")
        {:ok, _} = Presence.track(self(), "lv:homepage", user.id, %{user_id: user.id, name: user.name, cursor_x: 0, cursor_y: 0, node: Node.self()})

        assign(socket, :anonymous_user, user)
      else
        assign(socket, :anonymous_user, %AnonymousUser{})
      end

    {:ok, assign(socket, :users, [])}
  end

  @impl Phoenix.LiveView
  def handle_info(%{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    users =
      socket.assigns.users
      |> join_users(joins)
      |> leave_users(leaves)

    socket = assign(socket, :users, users)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="w-full space-y-4">
      <div>
        <p>Current Node - <%= inspect(Node.self()) %></p>
      </div>
      <div>
        <p>Other nodes:</p>
        <ul>
          <%= for node <- Node.list() do %>
            <li><%= inspect(node) %></li>
          <% end %>
        </ul>
      </div>
      <div>
        <p>All Users (including current):</p>
        <ul class="space-y-2">
          <%= for user <- @users do %>
            <li><%= user.name %> - <%= inspect(user.node) %></li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  defp create_anonymous_user do
    struct!(AnonymousUser, %{id: Faker.UUID.v4(), name: Faker.Person.name()})
  end

  defp join_users(users, joins) do
   joined_users = Enum.flat_map(joins, fn join ->
    join |> elem(1) |> Map.fetch!(:metas)
   end)

   Enum.concat(joined_users, users)
  end

  defp leave_users(users, leaves) do
    Enum.reject(users, & &1.user_id == Map.keys(leaves))
  end
end
