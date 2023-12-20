defmodule ClusterApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ClusterAppWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: ClusterApp.PubSub},
      # Add Presence on top of PubSub
      ClusterAppWeb.Presence,
      # Start Finch
      {Finch, name: ClusterApp.Finch},
      # Start the Endpoint (http/https)
      ClusterAppWeb.Endpoint
      # Start a worker by calling: ClusterApp.Worker.start_link(arg)
      # {ClusterApp.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ClusterApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ClusterAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
