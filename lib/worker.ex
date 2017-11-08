defmodule OpenWeatherMap.Worker do
  def temperature_of(location) do
    result = url_for(location) |> HTTPoison.get |> parse_response
    # without using the pipe operator, you'd have to write the function like so:
    # result = parse_response(HTTPoison.get(url_for(location)))

    case result do
      {:ok, temp} ->
        "#{location}: #{temp}°C"
      :error ->
        "#{location} not found"
    end
  end

  defp url_for(location) do
    location = URI.encode(location)
    "http://api.openweathermap.org/data/2.5/weather?q=#{location}&appid=#{apikey()}"
  end

  defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
    body |> JSON.decode! |> compute_temperature
  end

  defp parse_response(_) do
    :error
  end

  defp compute_temperature(json) do
    try do
      temp = (json["main"]["temp"] - 273.15) |> Float.round(1)
      {:ok, temp}
    rescue
      _ -> :error
    end
  end

  defp apikey do
    Application.fetch_env!(:open_weather_map, :api_key)
  end
end
