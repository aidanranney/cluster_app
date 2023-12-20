defmodule ClusterAppWeb.Presence do
  use Phoenix.Presence, otp_app: :cluster_app, pubsub_server: ClusterApp.PubSub
end
