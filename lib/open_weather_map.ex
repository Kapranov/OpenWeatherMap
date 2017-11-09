defmodule OpenWeatherMap do
  use Application

  def start(_type, _args) do
    cowboy_options = [
      #keyfile:  "priv/keys/localhost.key",
      #certfile: "priv/keys/localhost.cert",
      port: 8880,
      otp_app:  :open_weather_map
    ]

    children = [
      Plug.Adapters.Cowboy.child_spec(
        # :https,
        :http,
        OpenWeatherMap.HelloPlug,
        [],
        cowboy_options
      )
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def temperatures_of(cities) do
    coordinator_pid = spawn(OpenWeatherMap.Coordinator, :loop, [[], Enum.count(cities)])

    cities |> Enum.each(fn city ->
      worker_pid = spawn(OpenWeatherMap.Worker, :loop, [])
      send worker_pid, {coordinator_pid, city}
    end)
  end
end
