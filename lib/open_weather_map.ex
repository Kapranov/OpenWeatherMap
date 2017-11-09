defmodule OpenWeatherMap do
  use Application
  use Export.Ruby

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

  def ruby_call_hello do
    {:ok, ruby} = Ruby.start(ruby_lib: Path.expand("lib/ruby"))
    ruby |> Ruby.call("ruby", "hello_world", [])
  end

  def ruby_call(name) do
    {:ok, ruby} = Ruby.start(ruby_lib: Path.expand("lib/ruby"))
    ruby |> Ruby.call("ruby", "hello", [name])
  end

  def ruby_call_sum(n, m) do
    {:ok, ruby} = Ruby.start(ruby_lib: Path.expand("lib/ruby"))
    ruby |> Ruby.call(sum_two_integers(n, m), from_file: "ruby")
  end

  def ruby_call_pdf do
    {:ok, ruby} = Ruby.start(ruby_lib: Path.expand("lib/ruby"))
    ruby |> Ruby.call("ruby", "generate_pdf", [])
  end
end
