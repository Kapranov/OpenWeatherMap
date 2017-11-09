require "prawn"

def hello_world
  result = "Hello, World Ruby!"
  puts result
  Tuple.new([:ok, result])
end

def hello(name)
  result = "Hello #{name}"
  puts result
  Tuple.new([:ok, result])
end

def sum_two_integers(n, m)
  result = n + m
  puts "The sum two integers is #{result} by Elixir function"
  Tuple.new([:ok, result])
end

def generate_pdf
  Prawn::Document.generate("ruby_prawn_elixir.pdf") do
    text "PDF generated with Ruby, Elixir and Prawn"
  end
  result = "PDF has been created!"
  puts result
  Tuple.new([:ok, result])
end
