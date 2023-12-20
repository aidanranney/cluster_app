defmodule ClusterAppWeb.HomePageLive do
  use ClusterAppWeb, :live_view

  alias ClusterApp.AnonymousUser


  def mount(_params, _session, socket) do
    {:ok, assign_async(socket, :anonymous_user, fn -> {:ok, %{anonymous_user: create_anonymous_user()}} end)}
  end

  def render(assigns) do
    ~H"""
    <div class="w-full">
      <.async_result :let={user} assign={@anonymous_user}>
        <%= user.name %> - <%= inspect(Node.self()) %>
      </.async_result>
    </div>
    """
  end

  defp create_anonymous_user do
    struct!(AnonymousUser, %{id: Faker.UUID.v4(), name: Faker.Person.name()})
  end
end
