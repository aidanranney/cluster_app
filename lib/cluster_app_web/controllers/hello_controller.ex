defmodule ClusterAppWeb.HelloController do
  use ClusterAppWeb, :controller

  def hello(conn, params) do
    name = Map.get(params, "name", "World")

    conn |> put_status(200) |> text("Hello #{name}")
  end

  def echo(conn, params) do
    conn |> put_status(200) |> json(inspect(params))
  end
end
