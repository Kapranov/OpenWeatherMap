defmodule OpenWeatherMap.Ruby do
  use Export.Ruby

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
