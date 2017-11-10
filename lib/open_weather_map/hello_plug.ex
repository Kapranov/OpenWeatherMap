defmodule OpenWeatherMap.HelloPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, "<h1>Open Weather Map is running!</h1>")
  end

  def fetch_pages() do
    IO.puts("The fetch_pages/0 routine has just been called at #{:os.system_time(:milli_seconds)}")
    fetch_pages()
  end
end
