defmodule ClusterAppWeb.HomePageLive do
  use ClusterAppWeb, :live_view

  alias ClusterApp.AnonymousUser
  alias ClusterAppWeb.Presence

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      if connected?(socket) do
        user = create_anonymous_user()
        {:ok, _} =
          Presence.track(self(), topic(), user.id, %{
            user_id: user.id,
            name: user.name,
            cursor_x: 0,
            cursor_y: 0,
            node: Node.self()
          })

        assign(socket, :anonymous_user, user)
      else
        assign(socket, :anonymous_user, %AnonymousUser{})
      end

    socket = assign(socket, other_users: [], messages: [])

    ClusterAppWeb.Endpoint.subscribe(topic())

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(%{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    joins = exclude_current_user(joins, socket.assigns.anonymous_user)

    other_users =
      socket.assigns.other_users
      |> leave_users(leaves)
      |> join_users(joins)

    cursor_updates_params = Enum.reduce(other_users, %{}, fn user, acc ->
      {params, _rest} = Map.split(user, [:cursor_x, :cursor_y])
      Map.put(acc, user.user_id, params)
    end)

    socket =
      socket
      |> assign(:other_users, other_users)
      |> push_event("update_cursors", cursor_updates_params)

    {:noreply, socket}
  end

  def handle_info(%{event: "received_message", payload: %{user: user, message: message}}, socket) do
      socket = assign(socket, :messages, ["#{user.name} - #{message}" | socket.assigns.messages])
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("move", %{"cursor_x" => cursor_x, "cursor_y" => cursor_y}, socket) do
    {:ok, _} =
      Presence.update(self(), topic(), socket.assigns.anonymous_user.id, fn metas ->
        Map.merge(metas, %{cursor_x: cursor_x, cursor_y: cursor_y})
      end)

    {:noreply, socket}
  end

  def handle_event("submit_message", %{"message" => message}, socket) do
    ClusterAppWeb.Endpoint.broadcast(topic(), "received_message", %{user: socket.assigns.anonymous_user, message: message})

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div id="cursor-canvas-root" phx-hook="TrackCursorMovement" class="absolute left-0 w-full h-full bg-blue-100 space-y-4">
      <div class="rounded relative mt-12 m-8 p-8 w-72 min-h-20 bg-lime-50">
        <ul>
        <%= for message <- @messages do %>
          <li><%= message %></li>
        <% end %>
        </ul>
      </div>
      <.form :let={form} for={%{}} phx-submit="submit_message" class="pl-8 flex gap-x-12">
        <.input field={form[:message]} />
        <button class="py-1 px-2 m-4 border border-blue-300 active:ring rounded hover:bg-blue-300 transition" type="submit">Submit Message</button>
      </.form>
      <%= for user <- @other_users do %>
        <div id={user.user_id} class="absolute before:content-['👆']">
          <p class={"text-#{pick_color()}-200 text-sm font-semibold"}><%= user.name %></p>
        </div>
      <% end %>
    </div>
    """
  end

  defp create_anonymous_user do
    struct!(AnonymousUser, %{id: Faker.UUID.v4(), name: Faker.Person.name()})
  end

  defp join_users(other_users, joins) do
    joins
    |> Enum.map(fn {_user_id, data} -> data[:metas] |> List.first() |> Map.delete(:phx_ref) end)
    |> Enum.filter(& &1.cursor_x != 0 and &1.cursor_y != 0)
    |> Enum.concat(other_users)
    |> Enum.uniq_by(& &1.user_id)
  end

  defp leave_users(other_users, leaves) do
    ids =
      Enum.map(leaves, fn {_user_id, data} ->
        data[:metas] |> List.first() |> Map.fetch!(:user_id)
      end)

    Enum.reject(other_users, &(&1.user_id in ids))
  end

  defp exclude_current_user(joins, current_user) do
    Map.reject(joins, fn {user_id, _data} -> user_id == current_user.id end)
  end

  defp topic, do: "lv:homepage"

  defp pick_color, do: Enum.random(["blue", "green", "grey", "red", "yellow"])
end
