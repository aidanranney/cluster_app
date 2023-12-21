defmodule ClusterAppWeb.HomePageLive do
  use ClusterAppWeb, :live_view

  alias ClusterApp.AnonymousUser
  alias ClusterAppWeb.Presence


  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      if connected?(socket) do
        user = create_anonymous_user()
        ClusterAppWeb.Endpoint.subscribe(topic())
        {:ok, _} = Presence.track(self(), topic(), user.id, %{user_id: user.id, name: user.name, cursor_x: 0, cursor_y: 0, node: Node.self()})
        send(self(), :after_join)

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

  def handle_info(:after_join, socket) do
    joined =
      topic()
      |> Presence.list()

    users = join_users(socket.assigns.users, joined)

    {:noreply, assign(socket, :users, users)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="w-full space-y-4">
      <div>
        <p>Current Node - <%= inspect(Node.self()) %></p>
        <p>Current User - <%= @anonymous_user.name %></p>
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
        <p>Connected users:</p>
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
    joins
    |> Enum.map(fn {_user_id, data} -> data[:metas] |> List.first() |> Map.delete(:phx_ref) end)
    |> Enum.concat(users)
    |> Enum.uniq_by(& &1.user_id)
  end

  defp leave_users(users, leaves) do
    ids = Enum.map(leaves, fn {_user_id, data} -> data[:metas] |> List.first() |> Map.fetch!(:user_id) end)

    Enum.reject(users, & &1.user_id in ids)
  end

  defp topic, do: "lv:homepage"
end
