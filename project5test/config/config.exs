# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :project5test, Project5testWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "OQp+B0Sg1lTrHEypPi5qbf3Ps/4k5A1YgOWyT7JgFGOhj/cNzGKh4e5IFzGKXZZU",
  render_errors: [view: Project5testWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Project5test.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
