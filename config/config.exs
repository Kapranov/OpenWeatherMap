use Mix.Config
import_config "#{Mix.env}.exs"

config :redis_connection_pool, [
  host: "127.0.0.1",
  port: 6379,
  password: "",
  db: 0,
  reconnect: :no_reconnect,
  pool_name: :"Redis.Pool",
  pool_size: 10,
  pool_max_overflow: 1
]
