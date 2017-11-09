defmodule OpenWeatherMap.HelloPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, "<h1>Open Weather Map is running!</h1>")
  end
end
