defmodule OpenWeatherMap do
  def temperatures_of(cities) do
    coordinator_pid = spawn(OpenWeatherMap.Coordinator, :loop, [[], Enum.count(cities)])

    cities |> Enum.each(fn city ->
      worker_pid = spawn(OpenWeatherMap.Worker, :loop, [])
      send worker_pid, {coordinator_pid, city}
    end)
  end
end
