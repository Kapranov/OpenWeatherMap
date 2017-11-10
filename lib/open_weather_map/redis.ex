defmodule OpenWeatherMap.Redis do
  @process_name :redis

  def get(key) do
    pid = Process.whereis(@process_name)
    Exredis.query(pid, ["get", key])
  end

  def set(key, value) do
    pid = Process.whereis(@process_name)
    Exredis.query(pid, ["set", key, value])
  end

  def start_link do
    {:ok, pid} = Exredis.start_link
    true = Process.register(pid, @process_name)
    {:ok, pid}
  end
end
