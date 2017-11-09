defmodule OpenWeatherMap.Mixfile do
  use Mix.Project

  def project do
    [
      app: :open_weather_map,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      compilers: [:elixir_make | Mix.compilers],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :redis_connection_pool],
      mod: {OpenWeatherMap, []}
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 1.1.2"},
      {:plug, "~> 1.4.3"},
      {:httpoison, "~> 0.13.0"},
      {:json, "~> 1.0.2"},
      {:redis_connection_pool, "~> 0.1.5"},
      {:elixir_make, "~> 0.4"}
    ]
  end
end
