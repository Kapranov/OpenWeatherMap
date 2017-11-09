include ErlPort::Erlang

def sum_two_integers(n, m)
  call('Elixir.OpenWeatherMap.Fancy'.to_sym, :sum_two_integers_in_elixir, [n, m])
end
