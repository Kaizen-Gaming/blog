# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :binary_data_over_phoenix_sockets, BinaryDataOverPhoenixSockets.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "xo27arOINbxytxKvRHu0xA/qDQ8ENVL2S8jNNzogQ6+AQZebIDsd5wFNKxvc1/ir",
  render_errors: [view: BinaryDataOverPhoenixSockets.ErrorView, accepts: ~w(html json)],
  pubsub: [name: BinaryDataOverPhoenixSockets.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
