use Mix.Config

config :absinthe_ecto, Absinthe.Ecto.TestRepo,
  hostname: "localhost",
  database: "absinthe_ecto_test",
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :warn
